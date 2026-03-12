import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rocket_reminder/src/app.dart';
import 'package:rocket_reminder/src/controller.dart';
import 'package:rocket_reminder/src/local_cache_base.dart';
import 'package:rocket_reminder/src/models.dart';
import 'package:rocket_reminder/src/rocket_goals_bridge_base.dart';

void main() {
  testWidgets('preview onboarding arms the app shell', (tester) async {
    final controller = GoalLockController(
      cache: _MemoryCache(),
      bridge: const _FakeBridge(),
      now: () => DateTime(2026, 3, 7, 5, 30),
    );

    await tester.pumpWidget(GoalLockApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Skip — preview without account'));
    await tester.tap(find.text('Skip — preview without account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Write my book');
    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Write my book'), findsWidgets);
    expect(find.text('Rocket Reminder'), findsOneWidget);
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
  }) async {
    return plan;
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
      ),
      credentials: RemoteCredentials(
        userId: 'linked-user',
        idToken: 'id-token',
        refreshToken: 'refresh-token',
        email: email,
      ),
      importedGoal: null,
      notice: null,
    );
  }

  @override
  Future<GoalPlan> upsertGoalPlan({
    required UserAccount account,
    required GoalPlan plan,
    required RemoteCredentials credentials,
    DailyCommitment? latestCommitment,
  }) {
    throw ArgumentError.value('bad sync payload');
  }
}
