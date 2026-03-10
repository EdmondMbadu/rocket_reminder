import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'goal_lock_notifications_base.dart';
import 'models.dart';

class _FlutterGoalLockNotifications implements GoalLockNotifications {
  _FlutterGoalLockNotifications();

  static const int _morningNotificationId = 4101;
  static const int _eveningNotificationId = 4102;
  static const String _channelId = 'goal_lock_daily';
  static const String _channelName = 'Goal Lock reminders';
  static const String _channelDescription =
      'Morning and evening Goal Lock reminders.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<bool> ensurePermissions() async {
    await initialize();

    var granted = true;

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }

    final macos = _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      granted = ((await macos.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              )) ??
              false) &&
          granted;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = (await android.requestNotificationsPermission() ?? true) &&
          granted;
    }

    return granted;
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancel(id: _morningNotificationId);
    await _plugin.cancel(id: _eveningNotificationId);
  }

  @override
  Future<void> scheduleMorningLock({
    required String goal,
    required int morningLockMinutes,
  }) async {
    await initialize();
    final when = _nextTimeOfDay(morningLockMinutes);
    await _plugin.zonedSchedule(
      id: _morningNotificationId,
      title: 'Goal Lock',
      body: 'What is the ONE thing you will do today for ${_compact(goal)}?',
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> scheduleEveningReflection(
    EveningReflectionReminder reminder,
  ) async {
    await initialize();
    final scheduledAt = tz.TZDateTime.from(reminder.when, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledAt.isAfter(now)) {
      return;
    }

    await _plugin.zonedSchedule(
      id: _eveningNotificationId,
      title: 'Goal Lock reflection',
      body: 'Did you do it? ${_compact(reminder.oneThing)}',
      scheduledDate: scheduledAt,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  tz.TZDateTime _nextTimeOfDay(int minutesOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      normalizeMinutesOfDay(minutesOfDay) ~/ 60,
      normalizeMinutesOfDay(minutesOfDay) % 60,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  String _compact(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 90) {
      return singleLine;
    }
    return '${singleLine.substring(0, 87)}...';
  }
}

GoalLockNotifications createPlatformGoalLockNotifications() =>
    _FlutterGoalLockNotifications();
