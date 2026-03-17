import 'platform_control_base.dart';
import 'platform_control_stub.dart'
    if (dart.library.io) 'platform_control_io.dart'
    as platform;

GoalLockPlatformControl createGoalLockPlatformControl() =>
    platform.createPlatformControl();
