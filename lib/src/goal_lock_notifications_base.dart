class EveningReflectionReminder {
  const EveningReflectionReminder({
    required this.goal,
    required this.oneThing,
    required this.when,
  });

  final String goal;
  final String oneThing;
  final DateTime when;
}

abstract class GoalLockNotifications {
  Future<void> initialize();

  Future<bool> ensurePermissions();

  Future<void> cancelAll();

  Future<void> scheduleMorningLock({
    required String goal,
    required int morningLockMinutes,
  });

  Future<void> scheduleEveningReflection(EveningReflectionReminder reminder);
}
