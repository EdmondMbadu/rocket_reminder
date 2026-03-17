package com.example.goal_lock

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

private const val platformChannelName = "goal_lock/platform"
private const val prefsName = "goal_lock_platform"
private const val requestNotificationsCode = 4401

class GoalLockPlatformPlugin(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, platformChannelName)
    private val prefs: SharedPreferences =
        activity.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
        GoalLockAlarmScheduler.createNotificationChannel(activity)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> {
                val includeInstalledApps =
                    (call.argument<Boolean>("includeInstalledApps") ?: false)
                result.success(buildStatus(includeInstalledApps))
            }

            "requestPlatformAuthorization" -> {
                result.success(buildStatus(includeInstalledApps = false))
            }

            "requestNotificationPermission" -> requestNotificationPermission(result)

            "openUsageAccessSettings" -> {
                activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success(buildStatus(includeInstalledApps = false))
            }

            "pickBlockedApps" -> {
                result.success(buildStatus(includeInstalledApps = false))
            }

            "configureSchedule" -> {
                configureSchedule(call)
                result.success(null)
            }

            "detectSlip" -> {
                result.success(detectSlip(call))
            }

            "clearSetup" -> {
                GoalLockAlarmScheduler.cancelAll(activity)
                prefs.edit().clear().apply()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != requestNotificationsCode) {
            return false
        }
        pendingNotificationPermissionResult?.success(buildStatus(includeInstalledApps = false))
        pendingNotificationPermissionResult = null
        return true
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(buildStatus(includeInstalledApps = false))
            return
        }
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(buildStatus(includeInstalledApps = false))
            return
        }
        pendingNotificationPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            requestNotificationsCode,
        )
    }

    private fun configureSchedule(call: MethodCall) {
        val morningLockMinutes = call.argument<Int>("morningLockMinutes") ?: return
        val reflectionLockMinutes = call.argument<Int>("reflectionLockMinutes") ?: return
        val selectedAppsRaw =
            call.argument<List<Map<String, Any?>>>("androidSelectedApps") ?: emptyList()
        val selectedApps = selectedAppsRaw.mapNotNull { raw ->
            val id = raw["id"] as? String ?: return@mapNotNull null
            val label = raw["label"] as? String ?: id
            GoalLockWatchedApp(id, label)
        }

        prefs.edit()
            .putInt("morningLockMinutes", morningLockMinutes)
            .putInt("reflectionLockMinutes", reflectionLockMinutes)
            .putStringSet(
                "selectedAppIds",
                selectedApps.map { it.id }.toSet(),
            )
            .putString(
                "selectedAppLabels",
                selectedApps.joinToString("|") { "${it.id}::${it.label}" },
            )
            .apply()

        GoalLockAlarmScheduler.scheduleAll(activity, prefs)
    }

    private fun detectSlip(call: MethodCall): Map<String, Any?>? {
        if (!usageAccessGranted()) {
            return null
        }
        val selectedAppIds = prefs.getStringSet("selectedAppIds", emptySet()).orEmpty()
        if (selectedAppIds.isEmpty()) {
            return null
        }
        val morningLockMinutes = call.argument<Int>("morningLockMinutes") ?: return null
        val reflectionLockMinutes = call.argument<Int>("reflectionLockMinutes") ?: return null
        if (!isWithinFocusWindow(morningLockMinutes, reflectionLockMinutes)) {
            return null
        }

        val usageStatsManager =
            activity.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - (15 * 60 * 1000), now)
        val event = UsageEvents.Event()
        var latestPackage: String? = null
        var latestTime = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isForeground = when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> true
                UsageEvents.Event.MOVE_TO_FOREGROUND -> true
                else -> false
            }
            if (!isForeground) {
                continue
            }
            if (event.packageName == activity.packageName) {
                continue
            }
            if (!selectedAppIds.contains(event.packageName)) {
                continue
            }
            if (event.timeStamp >= latestTime) {
                latestPackage = event.packageName
                latestTime = event.timeStamp
            }
        }

        if (latestPackage == null || latestTime == 0L) {
            return null
        }

        val lastReportedPackage = prefs.getString("lastSlipPackage", null)
        val lastReportedAt = prefs.getLong("lastSlipAt", 0L)
        if (latestPackage == lastReportedPackage && latestTime == lastReportedAt) {
            return null
        }

        prefs.edit()
            .putString("lastSlipPackage", latestPackage)
            .putLong("lastSlipAt", latestTime)
            .apply()

        return mapOf(
            "appId" to latestPackage,
            "label" to labelForPackage(latestPackage),
            "occurredAt" to Instant.ofEpochMilli(latestTime).toString(),
        )
    }

    private fun buildStatus(includeInstalledApps: Boolean): Map<String, Any?> {
        val selectedApps = prefs.getStringSet("selectedAppIds", emptySet()).orEmpty()
        return mapOf(
            "supported" to true,
            "canBlockApps" to false,
            "canDetectUsage" to true,
            "platformAuthorizationGranted" to usageAccessGranted(),
            "notificationsGranted" to notificationsGranted(),
            "usageAccessGranted" to usageAccessGranted(),
            "selectedAppsCount" to selectedApps.size,
            "installedApps" to if (includeInstalledApps) loadInstalledApps() else emptyList<Map<String, Any?>>(),
        )
    }

    private fun loadInstalledApps(): List<Map<String, Any?>> {
        val packageManager = activity.packageManager
        val launchIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(launchIntent, 0)
            .map { resolveInfo ->
                val label = resolveInfo.loadLabel(packageManager).toString()
                val packageName = resolveInfo.activityInfo.packageName
                mapOf(
                    "id" to packageName,
                    "label" to label,
                )
            }
            .distinctBy { it["id"] as String }
            .sortedBy { it["label"] as String }
    }

    private fun notificationsGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED && NotificationManagerCompat.from(activity)
                .areNotificationsEnabled()
        } else {
            NotificationManagerCompat.from(activity).areNotificationsEnabled()
        }
    }

    private fun usageAccessGranted(): Boolean {
        val appOps = activity.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                activity.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                activity.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun labelForPackage(packageName: String): String {
        return try {
            val info = activity.packageManager.getApplicationInfo(packageName, 0)
            activity.packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            packageName
        }
    }

    private fun isWithinFocusWindow(morningLockMinutes: Int, reflectionLockMinutes: Int): Boolean {
        val now = LocalDateTime.now()
        val nowMinutes = (now.hour * 60) + now.minute
        return if (morningLockMinutes < reflectionLockMinutes) {
            nowMinutes in morningLockMinutes until reflectionLockMinutes
        } else {
            nowMinutes >= morningLockMinutes || nowMinutes < reflectionLockMinutes
        }
    }
}

private data class GoalLockWatchedApp(
    val id: String,
    val label: String,
)

object GoalLockAlarmScheduler {
    private const val notificationChannelId = "goal_lock_focus"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            notificationChannelId,
            "Goal Lock Focus",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Goal Lock morning, noon, and evening reminders."
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    fun scheduleAll(context: Context, prefs: SharedPreferences) {
        createNotificationChannel(context)
        cancelAll(context)
        schedulePhase(context, prefs, "morning", prefs.getInt("morningLockMinutes", 390), 1001)
        schedulePhase(context, prefs, "noon", 12 * 60, 1002)
        schedulePhase(
            context,
            prefs,
            "evening",
            prefs.getInt("reflectionLockMinutes", (6 * 60) + 30 + (14 * 60)),
            1003,
        )
    }

    fun cancelAll(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        listOf(
            pendingIntent(context, "morning", 1001),
            pendingIntent(context, "noon", 1002),
            pendingIntent(context, "evening", 1003),
        ).forEach(alarmManager::cancel)
    }

    fun scheduleNext(context: Context, phase: String) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        when (phase) {
            "morning" -> schedulePhase(context, prefs, phase, prefs.getInt("morningLockMinutes", 390), 1001)
            "noon" -> schedulePhase(context, prefs, phase, 12 * 60, 1002)
            "evening" -> schedulePhase(
                context,
                prefs,
                phase,
                prefs.getInt("reflectionLockMinutes", (6 * 60) + 30 + (14 * 60)),
                1003,
            )
        }
    }

    fun notificationChannelId(): String = notificationChannelId

    private fun schedulePhase(
        context: Context,
        prefs: SharedPreferences,
        phase: String,
        minutesOfDay: Int,
        requestCode: Int,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = LocalDateTime.now()
        var triggerAt = now
            .withHour(minutesOfDay / 60)
            .withMinute(minutesOfDay % 60)
            .withSecond(0)
            .withNano(0)
        if (!triggerAt.isAfter(now)) {
            triggerAt = triggerAt.plusDays(1)
        }
        val triggerMillis = triggerAt.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerMillis,
            pendingIntent(context, phase, requestCode),
        )
    }

    private fun pendingIntent(
        context: Context,
        phase: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, GoalLockAlarmReceiver::class.java).apply {
            putExtra("phase", phase)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
