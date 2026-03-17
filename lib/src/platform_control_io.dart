import 'package:flutter/services.dart';

import 'models.dart';
import 'platform_control_base.dart';

class _MethodChannelPlatformControl implements GoalLockPlatformControl {
  static const MethodChannel _channel = MethodChannel('goal_lock/platform');

  const _MethodChannelPlatformControl();

  @override
  Future<void> clear() async {
    await _channel.invokeMethod<void>('clearSetup');
  }

  @override
  Future<void> configureSchedule({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  }) async {
    await _channel.invokeMethod<void>('configureSchedule', <String, dynamic>{
      'morningLockMinutes': plan.morningLockMinutes,
      'reflectionLockMinutes': plan.reflectionLockMinutes,
      'focusWindowHours': plan.focusWindowHours,
      'androidSelectedApps': androidSelectedApps
          .map((entry) => entry.toJson())
          .toList(),
    });
  }

  @override
  Future<PlatformSlipEvent?> detectSlip({
    required GoalPlan plan,
    required List<SelectableApp> androidSelectedApps,
  }) async {
    final raw = await _channel
        .invokeMapMethod<dynamic, dynamic>('detectSlip', <String, dynamic>{
          'morningLockMinutes': plan.morningLockMinutes,
          'reflectionLockMinutes': plan.reflectionLockMinutes,
          'androidSelectedApps': androidSelectedApps
              .map((entry) => entry.toJson())
              .toList(),
        });
    if (raw == null) {
      return null;
    }
    final map = raw.cast<String, dynamic>();
    final appId = map['appId'] as String? ?? '';
    final label = map['label'] as String? ?? '';
    final occurredAtRaw = map['occurredAt'] as String? ?? '';
    if (appId.isEmpty || label.isEmpty) {
      return null;
    }
    return PlatformSlipEvent(
      appId: appId,
      label: label,
      occurredAt: DateTime.tryParse(occurredAtRaw) ?? DateTime.now(),
    );
  }

  @override
  Future<PlatformStatus> getStatus({bool includeInstalledApps = false}) async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getStatus',
      <String, dynamic>{'includeInstalledApps': includeInstalledApps},
    );
    return _decodeStatus(raw);
  }

  @override
  Future<PlatformStatus> openUsageAccessSettings() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'openUsageAccessSettings',
    );
    return _decodeStatus(raw);
  }

  @override
  Future<PlatformStatus> pickBlockedApps() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'pickBlockedApps',
    );
    return _decodeStatus(raw);
  }

  @override
  Future<PlatformStatus> requestNotificationPermission() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'requestNotificationPermission',
    );
    return _decodeStatus(raw);
  }

  @override
  Future<PlatformStatus> requestPlatformAuthorization() async {
    final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
      'requestPlatformAuthorization',
    );
    return _decodeStatus(raw);
  }

  PlatformStatus _decodeStatus(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
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
    final map = raw.cast<String, dynamic>();
    final installedApps = (map['installedApps'] as List<dynamic>? ?? [])
        .map(
          (entry) => SelectableApp.fromJson(
            (entry as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
    return PlatformStatus(
      supported: map['supported'] as bool? ?? false,
      canBlockApps: map['canBlockApps'] as bool? ?? false,
      canDetectUsage: map['canDetectUsage'] as bool? ?? false,
      platformAuthorizationGranted:
          map['platformAuthorizationGranted'] as bool? ?? false,
      notificationsGranted: map['notificationsGranted'] as bool? ?? false,
      usageAccessGranted: map['usageAccessGranted'] as bool? ?? false,
      selectedAppsCount: map['selectedAppsCount'] as int? ?? 0,
      installedApps: installedApps,
    );
  }
}

GoalLockPlatformControl createPlatformControl() =>
    const _MethodChannelPlatformControl();
