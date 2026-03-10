import 'goal_lock_notifications_base.dart';

class _NoopGoalLockNotifications implements GoalLockNotifications {
  const _NoopGoalLockNotifications();

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> ensurePermissions() async => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleEveningReflection(
    EveningReflectionReminder reminder,
  ) async {}

  @override
  Future<void> scheduleMorningLock({
    required String goal,
    required int morningLockMinutes,
  }) async {}
}

GoalLockNotifications createPlatformGoalLockNotifications() =>
    const _NoopGoalLockNotifications();
