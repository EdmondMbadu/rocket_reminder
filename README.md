# Goal Lock

Goal Lock mobile app for Rocket Goals.

## Local config

Do not commit Firebase keys or other secrets into source.

Run linked-account flows with:

```bash
flutter run --dart-define=ROCKET_GOALS_FIREBASE_API_KEY=your_key_here
```

Without that define, debug builds can still use Preview mode.

## Billing

Goal Lock billing is wired to the same `rocket-prompt` Firebase project and
expects three deployed Cloud Functions from this repo:

- `goalLockCreateCheckoutSession`
- `goalLockCreateBillingPortalSession`
- `goalLockStripeWebhook`

Stripe setup you need:

1. Create a recurring monthly Stripe price for `$5.00/month`.
2. Create a one-time Stripe coupon for `$4.01` off so the first invoice becomes `$0.99`.
3. Set the functions secret values:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set GOAL_LOCK_STRIPE_WEBHOOK_SECRET
```

4. Copy `functions/.env.example` to `functions/.env` and fill in the real Stripe IDs/URLs.
5. Deploy the functions from this repo:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

6. Point a Stripe webhook at:

```text
https://us-central1-rocket-prompt.cloudfunctions.net/goalLockStripeWebhook
```

Use these Stripe event types:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

For local function testing, you can override the function base URL:

```bash
flutter run \
  --dart-define=ROCKET_GOALS_FIREBASE_API_KEY=your_key_here \
  --dart-define=ROCKET_GOALS_FUNCTIONS_ORIGIN=http://127.0.0.1:5001/rocket-prompt/us-central1
```
