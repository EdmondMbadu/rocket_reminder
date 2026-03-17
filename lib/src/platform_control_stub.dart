import 'models.dart';
import 'platform_control_base.dart';

class _UnsupportedPlatformControl implements GoalLockPlatformControl {
  const _UnsupportedPlatformControl();

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
      supported: false,
      canBlockApps: false,
      canDetectUsage: false,
      platformAuthorizationGranted: false,
      notificationsGranted: false,
      usageAccessGranted: false,
      selectedAppsCount: 0,
    );
  }

  @override
  Future<PlatformStatus> openUsageAccessSettings() async {
    return getStatus();
  }

  @override
  Future<PlatformStatus> pickBlockedApps() async {
    return getStatus();
  }

  @override
  Future<PlatformStatus> requestNotificationPermission() async {
    return getStatus();
  }

  @override
  Future<PlatformStatus> requestPlatformAuthorization() async {
    return getStatus();
  }
}

GoalLockPlatformControl createPlatformControl() =>
    const _UnsupportedPlatformControl();
