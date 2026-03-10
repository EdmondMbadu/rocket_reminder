import 'goal_lock_notifications_base.dart';
import 'goal_lock_notifications_stub.dart'
    if (dart.library.io) 'goal_lock_notifications_io.dart' as platform;

export 'goal_lock_notifications_base.dart';

GoalLockNotifications createGoalLockNotifications() =>
    platform.createPlatformGoalLockNotifications();
