import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:goal_lock/src/app.dart';
import 'package:goal_lock/src/controller.dart';
import 'package:goal_lock/src/local_cache_base.dart';
import 'package:goal_lock/src/models.dart';
import 'package:goal_lock/src/platform_control_base.dart';
import 'package:goal_lock/src/rocket_goals_bridge_base.dart';

void main() {
  testWidgets('preview onboarding arms the app shell', (tester) async {
    final controller = GoalLockController(
      cache: _MemoryCache(),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => DateTime(2026, 3, 7, 5, 30),
    );

    await tester.pumpWidget(GoalLockApp(controller: controller));
    await tester.pumpAndSettle();

    await controller.continueInPreview();
    await controller.armGoalLock(
      goal: 'Write my book',
      morningLockMinutes: 6 * 60 + 30,
      focusWindowHours: 14,
    );
    await tester.pumpAndSettle();

    expect(find.text('Write my book'), findsWidgets);
    expect(find.text('Goal Lock'), findsOneWidget);
  });

  testWidgets('morning lock accepts one thing and unlocks', (tester) async {
    final snapshot = GoalLockSnapshot(
      account: const UserAccount(
        userId: 'preview-user',
        firstName: 'Ava',
        lastName: 'Jordan',
        email: 'ava@preview.rocket',
        mode: ExperienceMode.preview,
        emailVerified: true,
      ),
      goalPlan: GoalPlan(
        goal: 'Launch my startup',
        morningLockMinutes: 6 * 60,
        focusWindowHours: 14,
        createdAt: DateTime(2026, 3, 1),
        armed: true,
        importedFromRocketGoals: false,
      ),
      commitments: const [],
    );

    final controller = GoalLockController(
      cache: _MemoryCache(seed: snapshot.toJson()),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => DateTime(2026, 3, 7, 8),
    );

    await tester.pumpWidget(GoalLockApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('What is the ONE thing'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'Call 3 design partners',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Call 3 design partners'), findsWidgets);
    expect(find.textContaining('What is the ONE thing'), findsNothing);
  });

  test(
    'linked goal arming falls back to local mode on unexpected sync errors',
    () async {
      final bridge = _ExplodingBridge();
      final controller = GoalLockController(
        cache: _MemoryCache(),
        bridge: bridge,
        platformControl: const _FakePlatformControl(),
        now: () => DateTime(2026, 3, 7, 6),
      );

      await controller.initialize();
      await controller.signIn(email: 'ava@rocket.test', password: 'secret123');
      await controller.armGoalLock(
        goal: 'Launch my startup',
        morningLockMinutes: 6 * 60,
        focusWindowHours: 14,
      );

      expect(controller.goalPlan?.goal, 'Launch my startup');
      expect(controller.goalPlan?.armed, isTrue);
      expect(
        controller.noticeMessage,
        'Goal Lock armed locally. Rocket Goals sync hit an unexpected error.',
      );
    },
  );

  test('goal plans normalize persisted schedule values', () {
    final plan = GoalPlan.fromJson(<String, dynamic>{
      'goal': 'Write my book',
      'morningLockMinutes': 24 * 60 + 37,
      'focusWindowHours': 40,
      'createdAt': '2026-03-07T06:00:00.000Z',
      'armed': true,
      'importedFromRocketGoals': true,
    });

    expect(plan.morningLockMinutes, 37);
    expect(plan.focusWindowHours, 16);
  });

  test(
    'arming a goal keeps the schedule locally without notifications',
    () async {
      final controller = GoalLockController(
        cache: _MemoryCache(),
        bridge: const _ExplodingBridge(),
        platformControl: const _FakePlatformControl(),
        now: () => DateTime(2026, 3, 7, 6),
      );

      await controller.initialize();
      await controller.signIn(email: 'ava@rocket.test', password: 'secret123');
      await controller.armGoalLock(
        goal: 'Write my book',
        morningLockMinutes: 7 * 60,
        focusWindowHours: 14,
      );

      expect(controller.goalPlan?.goal, 'Write my book');
      expect(controller.goalPlan?.morningLockMinutes, 7 * 60);
    },
  );

  test(
    'submitting the morning one thing prepares noon and evening checks in state',
    () async {
      final controller = GoalLockController(
        cache: _MemoryCache(),
        bridge: const _FakeBridge(),
        platformControl: const _FakePlatformControl(),
        now: () => DateTime(2026, 3, 7, 8),
      );

      await controller.initialize();
      await controller.continueInPreview();
      await controller.armGoalLock(
        goal: 'Launch my startup',
        morningLockMinutes: 6 * 60,
        focusWindowHours: 14,
      );
      await controller.submitMorningOneThing('Call 3 design partners');

      expect(controller.todayCommitment?.oneThing, 'Call 3 design partners');
      expect(controller.nextLockSummary(), 'Noon check-in at 12:00 PM.');
    },
  );

  testWidgets('noon lock accepts an on-track check-in', (tester) async {
    final snapshot = GoalLockSnapshot(
      account: const UserAccount(
        userId: 'preview-user',
        firstName: 'Ava',
        lastName: 'Jordan',
        email: 'ava@preview.rocket',
        mode: ExperienceMode.preview,
        emailVerified: true,
      ),
      goalPlan: GoalPlan(
        goal: 'Launch my startup',
        morningLockMinutes: 6 * 60,
        focusWindowHours: 14,
        createdAt: DateTime(2026, 3, 1),
        armed: true,
        importedFromRocketGoals: false,
      ),
      commitments: <DailyCommitment>[
        DailyCommitment(
          dateKey: '2026-03-07',
          oneThing: 'Call 3 design partners',
          committedAt: DateTime(2026, 3, 7, 8),
          middayOnTrack: null,
          middayCheckedAt: null,
          didComplete: null,
          reflectedAt: null,
        ),
      ],
    );

    final controller = GoalLockController(
      cache: _MemoryCache(seed: snapshot.toJson()),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => DateTime(2026, 3, 7, 12, 15),
    );

    await tester.pumpWidget(GoalLockApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Are you on track to do your one thing?'), findsOneWidget);
    expect(find.text('Call 3 design partners'), findsWidgets);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(find.text('Are you on track to do your one thing?'), findsNothing);
    expect(controller.todayCommitment?.middayOnTrack, isTrue);
  });

  test('refreshing after resume re-evaluates due checks immediately', () async {
    var now = DateTime(2026, 3, 7, 11, 59);
    final controller = GoalLockController(
      cache: _MemoryCache(
        seed: GoalLockSnapshot(
          account: const UserAccount(
            userId: 'preview-user',
            firstName: 'Ava',
            lastName: 'Jordan',
            email: 'ava@preview.rocket',
            mode: ExperienceMode.preview,
            emailVerified: true,
          ),
          goalPlan: GoalPlan(
            goal: 'Launch my startup',
            morningLockMinutes: 6 * 60,
            focusWindowHours: 14,
            createdAt: DateTime(2026, 3, 1),
            armed: true,
            importedFromRocketGoals: false,
          ),
          commitments: <DailyCommitment>[
            DailyCommitment(
              dateKey: '2026-03-07',
              oneThing: 'Call 3 design partners',
              committedAt: DateTime(2026, 3, 7, 8),
              middayOnTrack: null,
              middayCheckedAt: null,
              didComplete: null,
              reflectedAt: null,
            ),
          ],
        ).toJson(),
      ),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => now,
    );

    await controller.initialize();
    expect(controller.lockPhase, LockPhase.unlocked);

    now = DateTime(2026, 3, 7, 12, 1);
    controller.refreshLockState();

    expect(controller.lockPhase, LockPhase.noonLocked);
  });

  test('updating the goal changes the title and reminder copy', () async {
    final controller = GoalLockController(
      cache: _MemoryCache(),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => DateTime(2026, 3, 7, 8),
    );

    await controller.initialize();
    await controller.continueInPreview();
    await controller.armGoalLock(
      goal: 'Launch my startup',
      morningLockMinutes: 6 * 60,
      focusWindowHours: 14,
    );
    await controller.updateGoal('Write my book');

    expect(controller.goalLabel, 'Write my book');
    expect(controller.goalPlan?.goal, 'Write my book');
  });

  test(
    'linked users without billing access are gated behind the billing phase',
    () async {
      final controller = GoalLockController(
        cache: _MemoryCache(
          seed: GoalLockSnapshot(
            account: const UserAccount(
              userId: 'linked-user',
              firstName: 'Ava',
              lastName: 'Jordan',
              email: 'ava@rocket.test',
              mode: ExperienceMode.linked,
              emailVerified: true,
              goalLockAccessGranted: false,
            ),
            goalPlan: null,
            commitments: const [],
          ).toJson(),
        ),
        bridge: const _FakeBridge(),
        platformControl: const _FakePlatformControl(),
      );

      await controller.initialize();

      expect(controller.lockPhase, LockPhase.billing);
    },
  );

  test('admin accounts bypass billing even without a subscription', () async {
    final controller = GoalLockController(
      cache: _MemoryCache(
        seed: GoalLockSnapshot(
          account: const UserAccount(
            userId: 'admin-user',
            firstName: 'Edmond',
            lastName: 'Admin',
            email: 'admin@rocket.test',
            mode: ExperienceMode.linked,
            emailVerified: true,
            isAdmin: true,
            goalLockAccessGranted: false,
          ),
          goalPlan: null,
          commitments: const [],
        ).toJson(),
      ),
      bridge: const _FakeBridge(),
      platformControl: const _FakePlatformControl(),
    );

    await controller.initialize();

    expect(controller.lockPhase, LockPhase.onboarding);
  });

  test('sign in restores remote Goal Lock history', () async {
    final controller = GoalLockController(
      cache: _MemoryCache(),
      bridge: const _SignedInBridge(),
      platformControl: const _FakePlatformControl(),
      now: () => DateTime(2026, 3, 7, 8),
    );

    await controller.initialize();
    await controller.signIn(email: 'ava@rocket.test', password: 'secret123');

    expect(controller.commitments, hasLength(2));
    expect(controller.commitments.first.dateKey, '2026-03-07');
    expect(controller.commitments.first.oneThing, 'Call 3 design partners');
  });

  test(
    'sign out preserves welcome onboarding completion for returning auth',
    () async {
      final cache = _MemoryCache();
      final controller = GoalLockController(
        cache: cache,
        bridge: const _FakeBridge(),
        platformControl: const _FakePlatformControl(),
        now: () => DateTime(2026, 3, 7, 8),
      );

      await controller.initialize();
      await controller.continueInPreview();
      await controller.armGoalLock(
        goal: 'Write my book',
        morningLockMinutes: 6 * 60 + 30,
        focusWindowHours: 14,
      );
      await controller.markWelcomeOnboardingComplete();
      await controller.signOut();

      final signedOutState = await cache.readJson();
      expect(signedOutState?['hasCompletedWelcomeOnboarding'], isTrue);
      expect(signedOutState?['account'], isNull);
      expect(signedOutState?['goalPlan'], isNull);

      final nextController = GoalLockController(
        cache: cache,
        bridge: const _FakeBridge(),
        platformControl: const _FakePlatformControl(),
      );
      await nextController.initialize();

      expect(nextController.hasCompletedWelcomeOnboarding, isTrue);
      expect(nextController.lockPhase, LockPhase.auth);
    },
  );

  testWidgets(
    'returning signed-out users see auth instead of welcome onboarding',
    (tester) async {
      final controller = GoalLockController(
        cache: _MemoryCache(
          seed: const GoalLockSnapshot(
            account: null,
            goalPlan: null,
            commitments: [],
            hasCompletedWelcomeOnboarding: true,
          ).toJson(),
        ),
        bridge: const _FakeBridge(),
        platformControl: const _FakePlatformControl(),
      );

      await tester.pumpWidget(GoalLockApp(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.text('You tell us your goal, we make sure you do it!'),
        findsOneWidget,
      );
      expect(find.text('Get started'), findsNothing);
    },
  );

  test(
    'returning sign-in without an imported goal goes to setup, not welcome flow',
    () async {
      final controller = GoalLockController(
        cache: _MemoryCache(
          seed: const GoalLockSnapshot(
            account: null,
            goalPlan: null,
            commitments: [],
            hasCompletedWelcomeOnboarding: true,
          ).toJson(),
        ),
        bridge: const _ExplodingBridge(),
        platformControl: const _FakePlatformControl(),
      );

      await controller.initialize();
      await controller.signIn(email: 'ava@rocket.test', password: 'secret123');

      expect(controller.hasCompletedWelcomeOnboarding, isTrue);
      expect(controller.lockPhase, LockPhase.onboarding);
    },
  );
}

class _MemoryCache implements LocalCache {
  _MemoryCache({Map<String, dynamic>? seed}) : _data = seed;

  Map<String, dynamic>? _data;

  @override
  Future<void> clear() async {
    _data = null;
  }

  @override
  Future<Map<String, dynamic>?> readJson() async => _data;

  @override
  Future<void> writeJson(Map<String, dynamic> data) async {
    _data = Map<String, dynamic>.from(data);
  }
}

class _FakeBridge implements RocketGoalsBridge {
  const _FakeBridge();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<Uri> createGoalLockBillingPortalSession({
    required RemoteCredentials credentials,
  }) async {
    return Uri.parse('https://example.com/billing');
  }

  @override
  Future<Uri> createGoalLockCheckoutSession({
    required RemoteCredentials credentials,
  }) async {
    return Uri.parse('https://example.com/checkout');
  }

  @override
  Future<LinkedAccountBundle> refreshAccount({
    required RemoteCredentials credentials,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<LinkedAccountBundle> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
    List<DailyCommitment> commitments = const [],
  }) async {
    return plan;
  }
}

class _SignedInBridge extends _FakeBridge {
  const _SignedInBridge();

  @override
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  }) async {
    return LinkedAccountBundle(
      account: UserAccount(
        userId: 'linked-user',
        firstName: 'Ava',
        lastName: 'Jordan',
        email: email,
        mode: ExperienceMode.linked,
        emailVerified: true,
        goalLockAccessGranted: true,
      ),
      credentials: RemoteCredentials(
        userId: 'linked-user',
        idToken: 'id-token',
        refreshToken: 'refresh-token',
        email: email,
      ),
      importedGoal: GoalPlan(
        goal: 'Launch my startup',
        morningLockMinutes: 6 * 60,
        focusWindowHours: 14,
        createdAt: DateTime(2026, 3, 1),
        armed: true,
        importedFromRocketGoals: true,
      ),
      importedCommitments: <DailyCommitment>[
        DailyCommitment(
          dateKey: '2026-03-07',
          oneThing: 'Call 3 design partners',
          committedAt: DateTime(2026, 3, 7, 8),
          middayOnTrack: true,
          middayCheckedAt: DateTime(2026, 3, 7, 12, 5),
          didComplete: null,
          reflectedAt: null,
        ),
        DailyCommitment(
          dateKey: '2026-03-06',
          oneThing: 'Draft the launch email',
          committedAt: DateTime(2026, 3, 6, 8),
          middayOnTrack: true,
          middayCheckedAt: DateTime(2026, 3, 6, 12, 2),
          didComplete: true,
          reflectedAt: DateTime(2026, 3, 6, 20),
        ),
      ],
      notice: null,
    );
  }
}

class _ExplodingBridge extends _FakeBridge {
  const _ExplodingBridge();

  @override
  Future<LinkedAccountBundle> signIn({
    required String email,
    required String password,
  }) async {
    return LinkedAccountBundle(
      account: UserAccount(
        userId: 'linked-user',
        firstName: 'Ava',
        lastName: 'Jordan',
        email: email,
        mode: ExperienceMode.linked,
        emailVerified: true,
        goalLockAccessGranted: true,
      ),
      credentials: RemoteCredentials(
        userId: 'linked-user',
        idToken: 'id-token',
        refreshToken: 'refresh-token',
        email: email,
      ),
      importedGoal: null,
      importedCommitments: const [],
      notice: null,
    );
  }

  @override
  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
    List<DailyCommitment> commitments = const [],
  }) {
    throw ArgumentError.value('bad sync payload');
  }
}

class _FakePlatformControl implements GoalLockPlatformControl {
  const _FakePlatformControl();

  @override
  Future<void> clear() async {}

  @override
  Future<void> configureSchedule({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  }) async {}

  @override
  Future<PlatformSlipEvent?> detectSlip({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  }) async {
    return null;
  }

  @override
  Future<PlatformStatus> getStatus({bool includeInstalledApps = false}) async {
    return const PlatformStatus(
      supported: true,
      canBlockApps: false,
      canDetectUsage: false,
      platformAuthorizationGranted: false,
      notificationsGranted: true,
      usageAccessGranted: true,
      selectedAppsCount: 1,
    );
  }

  @override
  Future<PlatformStatus> openUsageAccessSettings() async => getStatus();

  @override
  Future<PlatformStatus> pickBlockedApps() async => getStatus();

  @override
  Future<PlatformStatus> requestNotificationPermission() async => getStatus();

  @override
  Future<PlatformStatus> requestPlatformAuthorization() async => getStatus();
}
