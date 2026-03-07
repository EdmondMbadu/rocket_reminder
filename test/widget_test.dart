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

    await tester.ensureVisible(find.text('Preview the product'));
    await tester.tap(find.text('Preview the product'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Write my book');
    await tester.ensureVisible(find.text('Arm Goal Lock'));
    await tester.tap(find.text('Arm Goal Lock'));
    await tester.pumpAndSettle();

    expect(find.text('Write my book'), findsWidgets);
    expect(find.text('Mission Orbit'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField).first, 'Call 3 design partners');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Unlock the day'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Call 3 design partners'), findsWidgets);
    expect(find.textContaining('What is the ONE thing'), findsNothing);
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
