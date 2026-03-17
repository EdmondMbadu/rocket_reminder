import 'models.dart';

class PlatformSlipEvent {
  const PlatformSlipEvent({
    required this.appId,
    required this.label,
    required this.occurredAt,
  });

  final String appId;
  final String label;
  final DateTime occurredAt;
}

class PlatformStatus {
  const PlatformStatus({
    required this.supported,
    required this.canBlockApps,
    required this.canDetectUsage,
    required this.platformAuthorizationGranted,
    required this.notificationsGranted,
    required this.usageAccessGranted,
    required this.selectedAppsCount,
    this.installedApps = const [],
  });

  final bool supported;
  final bool canBlockApps;
  final bool canDetectUsage;
  final bool platformAuthorizationGranted;
  final bool notificationsGranted;
  final bool usageAccessGranted;
  final int selectedAppsCount;
  final List<SelectableApp> installedApps;
}

abstract class GoalLockPlatformControl {
  Future<PlatformStatus> getStatus({bool includeInstalledApps = false});

  Future<PlatformStatus> requestPlatformAuthorization();

  Future<PlatformStatus> requestNotificationPermission();

  Future<PlatformStatus> openUsageAccessSettings();

  Future<PlatformStatus> pickBlockedApps();

  Future<void> configureSchedule({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  });

  Future<PlatformSlipEvent?> detectSlip({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  });

  Future<void> clear();
}
