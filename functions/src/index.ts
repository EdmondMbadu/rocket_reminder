import * as admin from 'firebase-admin';
import { defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import * as crypto from 'node:crypto';

import Stripe from 'stripe';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const goalLockStripeWebhookSecret = defineSecret(
  'GOAL_LOCK_STRIPE_WEBHOOK_SECRET',
);

const goalLockMonthlyPriceId =
  process.env.GOAL_LOCK_STRIPE_MONTHLY_PRICE_ID ??
  'price_1TA2KfG26VVCdyeuEmXxpO7C';
const goalLockIntroCouponId =
  process.env.GOAL_LOCK_STRIPE_INTRO_COUPON_ID ?? '54BdjulH';
const goalLockSuccessUrl =
  process.env.GOAL_LOCK_STRIPE_SUCCESS_URL ?? 'https://www.rocketgoals.com';
const goalLockCancelUrl =
  process.env.GOAL_LOCK_STRIPE_CANCEL_URL ?? 'https://www.rocketgoals.com';
const goalLockPortalReturnUrl =
  process.env.GOAL_LOCK_STRIPE_PORTAL_RETURN_URL ?? goalLockSuccessUrl;

const goalLockStripeEvents = new Set([
  'checkout.session.completed',
  'checkout.session.async_payment_succeeded',
  'checkout.session.async_payment_failed',
  'customer.subscription.created',
  'customer.subscription.updated',
  'customer.subscription.deleted',
  'invoice.payment_succeeded',
  'invoice.payment_failed',
]);

type ProfileData = FirebaseFirestore.DocumentData & {
  admin?: boolean;
  role?: string;
  email?: string;
  firstName?: string;
  lastName?: string;
  goalLockAccessGranted?: boolean;
  goalLockIntroOfferUsed?: boolean;
  goalLockStripeCustomerId?: string;
  goalLockStripeSubscriptionId?: string;
  goalLockSubscriptionStatus?: string;
  goalLockSubscriptionExpiresAt?: FirebaseFirestore.Timestamp | null;
};

type HttpRequest = any;
type HttpResponse = any;

const setCorsHeaders = (res: HttpResponse) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
};

const handleOptions = (req: HttpRequest, res: HttpResponse) => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
};

const sendJson = (res: HttpResponse, status: number, payload: unknown) => {
  setCorsHeaders(res);
  res.status(status).json(payload);
};

const toTimestamp = (unixSeconds?: number | null) => {
  if (!unixSeconds) {
    return null;
  }
  return admin.firestore.Timestamp.fromMillis(unixSeconds * 1000);
};

const isAdminProfile = (profile: ProfileData) =>
  profile.admin === true || profile.role === 'admin';

const hasGoalLockAccess = (profile: ProfileData) => {
  if (isAdminProfile(profile) || profile.goalLockAccessGranted === true) {
    return true;
  }

  const status = profile.goalLockSubscriptionStatus?.trim().toLowerCase();
  if (status === 'active' || status === 'trialing' || status === 'canceling') {
    return true;
  }

  const expiresAt = profile.goalLockSubscriptionExpiresAt;
  return !!expiresAt && expiresAt.toMillis() > Date.now();
};

const stripeStatusGrantsAccess = (status: string | null | undefined) => {
  const normalized = status?.trim().toLowerCase();
  return normalized === 'active' || normalized === 'trialing';
};

const getStripe = () => {
  const secret = stripeSecretKey.value();
  if (!secret) {
    throw new Error('STRIPE_SECRET_KEY is not configured.');
  }
  return new Stripe(secret);
};

const getWebhookSecret = () => {
  const secret = goalLockStripeWebhookSecret.value();
  if (!secret) {
    throw new Error('GOAL_LOCK_STRIPE_WEBHOOK_SECRET is not configured.');
  }
  return secret;
};

const requireGoalLockPriceId = () => {
  if (!goalLockMonthlyPriceId) {
    throw new Error('GOAL_LOCK_STRIPE_MONTHLY_PRICE_ID is not configured.');
  }
  return goalLockMonthlyPriceId;
};

const extractBearerToken = (req: HttpRequest) => {
  const authorization = req.headers.authorization;
  if (!authorization || !authorization.startsWith('Bearer ')) {
    return null;
  }
  return authorization.slice('Bearer '.length).trim();
};

const authenticateRequest = async (req: HttpRequest) => {
  const token = extractBearerToken(req);
  if (!token) {
    throw new Error('Authentication required.');
  }
  return admin.auth().verifyIdToken(token);
};

const userProfiles = () => admin.firestore().collection('userProfiles');

const resolveProfileRef = async ({
  customerId,
  subscriptionId,
  firebaseUserId,
  clientReferenceId,
}: {
  customerId?: string | null;
  subscriptionId?: string | null;
  firebaseUserId?: string | null;
  clientReferenceId?: string | null;
}) => {
  const directUserId = firebaseUserId || clientReferenceId;
  if (directUserId) {
    const docRef = userProfiles().doc(directUserId);
    const snapshot = await docRef.get();
    if (snapshot.exists) {
      return docRef;
    }
  }

  if (subscriptionId) {
    const snapshot = await userProfiles()
      .where('goalLockStripeSubscriptionId', '==', subscriptionId)
      .limit(1)
      .get();
    if (!snapshot.empty) {
      return snapshot.docs[0].ref;
    }
  }

  if (customerId) {
    const snapshot = await userProfiles()
      .where('goalLockStripeCustomerId', '==', customerId)
      .limit(1)
      .get();
    if (!snapshot.empty) {
      return snapshot.docs[0].ref;
    }
  }

  return null;
};

const ensureGoalLockCustomer = async ({
  stripe,
  userId,
  profile,
}: {
  stripe: Stripe;
  userId: string;
  profile: ProfileData;
}) => {
  const existingCustomerId = profile.goalLockStripeCustomerId?.trim();
  if (existingCustomerId) {
    return existingCustomerId;
  }

  const customer = await stripe.customers.create({
    email: profile.email,
    name: `${profile.firstName ?? ''} ${profile.lastName ?? ''}`.trim() || undefined,
    metadata: {
      app: 'goal_lock',
      firebaseUserId: userId,
    },
  });

  await userProfiles().doc(userId).set(
    {
      goalLockStripeCustomerId: customer.id,
    },
    { merge: true },
  );

  return customer.id;
};

const parseStripeSignature = (header: string) => {
  const parts = header.split(',').map((part) => part.trim());
  const timestampPart = parts.find((part) => part.startsWith('t='));
  const timestamp = timestampPart ? Number(timestampPart.slice(2)) : null;
  const signatures = parts
    .filter((part) => part.startsWith('v1='))
    .map((part) => part.slice(3));
  return { timestamp, signatures };
};

const timingSafeEqual = (a: string, b: string) => {
  const aBuffer = Buffer.from(a, 'utf8');
  const bBuffer = Buffer.from(b, 'utf8');
  if (aBuffer.length !== bBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(aBuffer, bBuffer);
};

const verifyStripeSignature = ({
  rawBody,
  signatureHeader,
  secret,
}: {
  rawBody: Buffer;
  signatureHeader: string;
  secret: string;
}) => {
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);
  if (!timestamp || signatures.length === 0) {
    return false;
  }

  const ageInSeconds = Math.abs(Date.now() / 1000 - timestamp);
  if (ageInSeconds > 300) {
    return false;
  }

  const payload = `${timestamp}.${rawBody.toString('utf8')}`;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  return signatures.some((signature) => timingSafeEqual(signature, expected));
};

const normalizeSubscriptionStatus = (subscription: Stripe.Subscription) => {
  if (
    subscription.cancel_at_period_end &&
    stripeStatusGrantsAccess(subscription.status)
  ) {
    return 'canceling';
  }
  return subscription.status;
};

export const goalLockCreateCheckoutSession = onRequest(
  {
    region: 'us-central1',
    secrets: [stripeSecretKey],
  },
  async (req, res) => {
    if (handleOptions(req, res)) {
      return;
    }
    if (req.method !== 'POST') {
      sendJson(res, 405, { error: 'Method not allowed.' });
      return;
    }

    try {
      const decodedToken = await authenticateRequest(req);
      const userRef = userProfiles().doc(decodedToken.uid);
      const snapshot = await userRef.get();
      if (!snapshot.exists) {
        sendJson(res, 404, { error: 'User profile not found.' });
        return;
      }

      const profile = (snapshot.data() ?? {}) as ProfileData;
      if (isAdminProfile(profile)) {
        await userRef.set({ goalLockAccessGranted: true }, { merge: true });
        sendJson(res, 200, { accessGranted: true });
        return;
      }

      if (hasGoalLockAccess(profile)) {
        sendJson(res, 200, { accessGranted: true });
        return;
      }

      const priceId = requireGoalLockPriceId();
      const stripe = getStripe();
      const customerId = await ensureGoalLockCustomer({
        stripe,
        userId: decodedToken.uid,
        profile,
      });

      const introEligible = profile.goalLockIntroOfferUsed !== true;
      if (introEligible && !goalLockIntroCouponId) {
        throw new Error(
          'GOAL_LOCK_STRIPE_INTRO_COUPON_ID is not configured.',
        );
      }

      const introApplied = introEligible && goalLockIntroCouponId.length > 0;

      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        mode: 'subscription',
        payment_method_types: ['card'],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        discounts: introApplied ? [{ coupon: goalLockIntroCouponId }] : undefined,
        success_url: goalLockSuccessUrl,
        cancel_url: goalLockCancelUrl,
        client_reference_id: decodedToken.uid,
        metadata: {
          app: 'goal_lock',
          firebaseUserId: decodedToken.uid,
          introApplied: String(introApplied),
        },
        subscription_data: {
          metadata: {
            app: 'goal_lock',
            firebaseUserId: decodedToken.uid,
            introApplied: String(introApplied),
          },
        },
      });

      await userRef.set(
        {
          goalLockStripeCustomerId: customerId,
          goalLockLastCheckoutSessionId: session.id,
          goalLockLastCheckoutAt:
            admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      sendJson(res, 200, {
        url: session.url,
        introApplied,
      });
    } catch (error) {
      console.error('Failed to create Goal Lock checkout session', error);
      sendJson(res, 500, {
        error:
          error instanceof Error
            ? error.message
            : 'Failed to create checkout session.',
      });
    }
  },
);

export const goalLockCreateBillingPortalSession = onRequest(
  {
    region: 'us-central1',
    secrets: [stripeSecretKey],
  },
  async (req, res) => {
    if (handleOptions(req, res)) {
      return;
    }
    if (req.method !== 'POST') {
      sendJson(res, 405, { error: 'Method not allowed.' });
      return;
    }

    try {
      const decodedToken = await authenticateRequest(req);
      const snapshot = await userProfiles().doc(decodedToken.uid).get();
      if (!snapshot.exists) {
        sendJson(res, 404, { error: 'User profile not found.' });
        return;
      }

      const profile = (snapshot.data() ?? {}) as ProfileData;
      if (isAdminProfile(profile)) {
        sendJson(res, 400, { error: 'Admins do not need billing access.' });
        return;
      }

      const customerId = profile.goalLockStripeCustomerId?.trim();
      if (!customerId) {
        sendJson(res, 412, { error: 'No Goal Lock billing profile found.' });
        return;
      }

      const stripe = getStripe();
      const session = await stripe.billingPortal.sessions.create({
        customer: customerId,
        return_url: goalLockPortalReturnUrl,
      });

      sendJson(res, 200, { url: session.url });
    } catch (error) {
      console.error('Failed to create Goal Lock billing portal session', error);
      sendJson(res, 500, {
        error:
          error instanceof Error
            ? error.message
            : 'Failed to create billing portal session.',
      });
    }
  },
);

export const goalLockStripeWebhook = onRequest(
  {
    region: 'us-central1',
    secrets: [goalLockStripeWebhookSecret],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      sendJson(res, 405, { error: 'Method not allowed.' });
      return;
    }

    try {
      const signatureHeader = req.headers['stripe-signature'];
      if (!signatureHeader || typeof signatureHeader !== 'string') {
        sendJson(res, 400, { error: 'Missing Stripe signature.' });
        return;
      }

      const rawBody = req.rawBody;
      if (!rawBody) {
        sendJson(res, 400, { error: 'Missing raw request body.' });
        return;
      }

      const secret = getWebhookSecret();
      if (
        !verifyStripeSignature({
          rawBody: Buffer.from(rawBody),
          signatureHeader,
          secret,
        })
      ) {
        sendJson(res, 400, { error: 'Invalid Stripe signature.' });
        return;
      }

      const event = JSON.parse(Buffer.from(rawBody).toString('utf8')) as Stripe.Event;
      if (!goalLockStripeEvents.has(event.type)) {
        sendJson(res, 200, { received: true });
        return;
      }

      switch (event.type) {
        case 'checkout.session.completed':
        case 'checkout.session.async_payment_succeeded':
        case 'checkout.session.async_payment_failed': {
          const session = event.data.object as Stripe.Checkout.Session;
          if (session.metadata?.app !== 'goal_lock') {
            break;
          }

          const profileRef = await resolveProfileRef({
            customerId:
              typeof session.customer === 'string' ? session.customer : null,
            subscriptionId:
              typeof session.subscription === 'string'
                ? session.subscription
                : null,
            firebaseUserId: session.metadata.firebaseUserId,
            clientReferenceId: session.client_reference_id,
          });

          if (!profileRef) {
            break;
          }

          const paymentSucceeded = session.payment_status === 'paid';
          await profileRef.set(
            {
              goalLockStripeCustomerId:
                typeof session.customer === 'string' ? session.customer : null,
              goalLockStripeSubscriptionId:
                typeof session.subscription === 'string'
                  ? session.subscription
                  : null,
              goalLockSubscriptionStatus: paymentSucceeded
                ? 'active'
                : session.payment_status,
              goalLockAccessGranted: paymentSucceeded,
              goalLockIntroOfferUsed:
                session.metadata.introApplied === 'true',
            },
            { merge: true },
          );
          break;
        }
        case 'customer.subscription.created':
        case 'customer.subscription.updated':
        case 'customer.subscription.deleted': {
          const subscription = event.data.object as Stripe.Subscription;
          const subscriptionData = subscription as Stripe.Subscription & {
            current_period_end?: number | null;
          };
          if (subscription.metadata?.app !== 'goal_lock') {
            break;
          }

          const profileRef = await resolveProfileRef({
            customerId:
              typeof subscription.customer === 'string'
                ? subscription.customer
                : null,
            subscriptionId: subscription.id,
            firebaseUserId: subscription.metadata.firebaseUserId,
          });

          if (!profileRef) {
            break;
          }

          const currentPriceId = subscription.items.data[0]?.price?.id ?? null;
          const normalizedStatus = normalizeSubscriptionStatus(subscription);

          await profileRef.set(
            {
              goalLockStripeCustomerId:
                typeof subscription.customer === 'string'
                  ? subscription.customer
                  : null,
              goalLockStripeSubscriptionId:
                event.type === 'customer.subscription.deleted'
                  ? null
                  : subscription.id,
              goalLockSubscriptionStatus:
                event.type === 'customer.subscription.deleted'
                  ? 'canceled'
                  : normalizedStatus,
              goalLockSubscriptionPriceId:
                event.type === 'customer.subscription.deleted'
                  ? null
                  : currentPriceId,
              goalLockSubscriptionExpiresAt: toTimestamp(
                subscriptionData.current_period_end,
              ),
              goalLockSubscriptionCancelAt: toTimestamp(
                subscription.cancel_at ??
                    (subscription.cancel_at_period_end
                        ? subscriptionData.current_period_end
                        : null),
              ),
              goalLockAccessGranted:
                event.type === 'customer.subscription.deleted'
                  ? false
                  : stripeStatusGrantsAccess(subscription.status),
              goalLockIntroOfferUsed:
                subscription.metadata.introApplied === 'true',
            },
            { merge: true },
          );
          break;
        }
        case 'invoice.payment_succeeded':
        case 'invoice.payment_failed': {
          const invoice = event.data.object as Stripe.Invoice;
          const invoiceData = invoice as Stripe.Invoice & {
            subscription?: string | null;
          };
          const metadataUserId =
            (invoice.parent as { subscription_details?: { metadata?: { firebaseUserId?: string } } } | null)
              ?.subscription_details?.metadata?.firebaseUserId ?? null;

          const profileRef = await resolveProfileRef({
            customerId:
              typeof invoice.customer === 'string' ? invoice.customer : null,
            subscriptionId:
              typeof invoiceData.subscription === 'string'
                ? invoiceData.subscription
                : null,
            firebaseUserId: metadataUserId,
          });

          if (!profileRef) {
            break;
          }

          const firstLine = invoice.lines.data[0] as Stripe.InvoiceLineItem & {
            price?: { id?: string | null } | null;
          };
          const paid = event.type === 'invoice.payment_succeeded';

          await profileRef.set(
            {
              goalLockStripeCustomerId:
                typeof invoice.customer === 'string' ? invoice.customer : null,
              goalLockStripeSubscriptionId:
                typeof invoiceData.subscription === 'string'
                  ? invoiceData.subscription
                  : null,
              goalLockSubscriptionStatus: paid
                ? 'active'
                : invoice.status || 'past_due',
              goalLockSubscriptionPriceId: firstLine?.price?.id ?? null,
              goalLockSubscriptionPaidAt: paid
                ? toTimestamp(
                    invoice.status_transitions?.paid_at ?? invoice.created,
                  )
                : null,
              goalLockSubscriptionExpiresAt: toTimestamp(
                firstLine?.period?.end ?? null,
              ),
              goalLockAccessGranted: paid,
            },
            { merge: true },
          );
          break;
        }
        default:
          break;
      }

      sendJson(res, 200, { received: true });
    } catch (error) {
      console.error('Failed to process Goal Lock Stripe webhook', error);
      sendJson(res, 500, {
        error:
          error instanceof Error
            ? error.message
            : 'Failed to process Stripe webhook.',
      });
    }
  },
);
