package com.example.goal_lock

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class GoalLockAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        GoalLockAlarmScheduler.createNotificationChannel(context)
        val phase = intent.getStringExtra("phase") ?: "morning"
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = PendingIntent.getActivity(
            context,
            phase.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val body = when (phase) {
            "morning" -> "Morning lock is live. Name the one move that matters today."
            "noon" -> "Noon check-in. Are you still on the one thing?"
            else -> "Evening reflection. Did you do it?"
        }

        val notification = NotificationCompat.Builder(
            context,
            GoalLockAlarmScheduler.notificationChannelId(),
        )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Goal Lock")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        NotificationManagerCompat.from(context).notify(phase.hashCode(), notification)
        GoalLockAlarmScheduler.scheduleNext(context, phase)
    }
}
