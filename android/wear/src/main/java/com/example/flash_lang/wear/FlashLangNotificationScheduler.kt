package com.example.flash_lang.wear

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.getSystemService
import java.time.LocalDateTime
import java.time.ZoneId

object FlashLangNotificationScheduler {
    const val CHANNEL_ID = "flashlang_wear_cards"
    const val EXTRA_CARD_ID = "extra_card_id"
    const val EXTRA_MODE = "extra_mode"
    const val EXTRA_TIME = "extra_time"
    const val EXTRA_INTERVAL_MINUTES = "extra_interval_minutes"
    private const val REQUEST_CODE_OFFSET = 10_000
    private const val PREFS_NAME = "flashlang_wear_schedule"
    private const val KEY_SCHEDULED_TIME_CODES = "scheduled_time_codes"
    private const val KEY_SCHEDULED_INTERVAL_CODE = "scheduled_interval_code"
    private const val TAG = "FlashLangWatchNotif"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService<NotificationManager>() ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "FlashLang Cards",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Flashcard reminders from FlashLang."
            },
        )
    }

    fun reschedule(context: Context) {
        try {
            cancelTracked(context)

            val snapshot = FlashLangSnapshotStore.loadSnapshot(context) ?: return
            if (snapshot.cards.isEmpty()) return

            when (snapshot.settings.scheduleMode) {
                FlashLangScheduleMode.INTERVAL -> {
                    val requestCode = scheduleInterval(
                        context,
                        snapshot.settings.intervalMinutes ?: 60,
                    )
                    persistScheduledIntervalCode(context, requestCode)
                    persistScheduledTimeCodes(context, emptyList())
                }

                FlashLangScheduleMode.FIXED_TIMES -> {
                    val requestCodes = snapshot.settings.pushTimes.mapNotNull { time ->
                        scheduleFixedTime(context, time)
                    }
                    persistScheduledTimeCodes(context, requestCodes)
                    persistScheduledIntervalCode(context, null)
                }
            }
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to reschedule notifications on watch.", error)
        }
    }

    fun handleAlarm(context: Context, intent: Intent) {
        showNextCardNotification(context)
        reschedule(context)
    }

    fun showNextCardNotification(context: Context) {
        ensureChannel(context)

        val card = FlashLangSnapshotStore.chooseNextCard(context) ?: return
        showCardNotification(
            context = context,
            cardId = card.id,
            title = card.notificationTitle(),
            meaning = card.meaning,
        )
        FlashLangSnapshotStore.markCardPushed(context, card.id)
    }

    fun showCardNotification(
        context: Context,
        cardId: Int,
        title: String,
        meaning: String,
    ) {
        ensureChannel(context)

        val detailIntent = Intent(context, CardDetailActivity::class.java).apply {
            putExtra(EXTRA_CARD_ID, cardId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            cardId,
            detailIntent,
            pendingIntentFlags(),
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(meaning)
            .setStyle(NotificationCompat.BigTextStyle().bigText(meaning))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        NotificationManagerCompat.from(context).notify(notificationIdForCard(cardId), notification)
    }

    fun cancelTracked(context: Context) {
        val alarmManager = context.getSystemService<AlarmManager>() ?: return

        readScheduledTimeCodes(context).forEach { requestCode ->
            alarmManager.cancel(pendingIntentFor(context, requestCode, Intent(context, FlashLangAlarmReceiver::class.java)))
        }

        readScheduledIntervalCode(context)?.let { requestCode ->
            alarmManager.cancel(pendingIntentFor(context, requestCode, Intent(context, FlashLangAlarmReceiver::class.java)))
        }
    }

    private fun scheduleFixedTime(context: Context, time: String): Int? {
        val minuteOfDay = parseMinuteOfDay(time)
        if (minuteOfDay < 0) return null

        val alarmManager = context.getSystemService<AlarmManager>() ?: return null
        val triggerAtMillis = nextRunForMinuteOfDay(minuteOfDay).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val requestCode = REQUEST_CODE_OFFSET + minuteOfDay

        val alarmIntent = Intent(context, FlashLangAlarmReceiver::class.java).apply {
            putExtra(EXTRA_MODE, FlashLangScheduleMode.FIXED_TIMES.name)
            putExtra(EXTRA_TIME, time)
        }

        scheduleAlarm(
            alarmManager = alarmManager,
            triggerAtMillis = triggerAtMillis,
            pendingIntent = pendingIntentFor(context, requestCode, alarmIntent),
        )

        return requestCode
    }

    private fun scheduleInterval(context: Context, intervalMinutes: Int): Int? {
        if (intervalMinutes <= 0) return null

        val alarmManager = context.getSystemService<AlarmManager>() ?: return null
        val triggerAtMillis = System.currentTimeMillis() + intervalMinutes * 60_000L
        val requestCode = REQUEST_CODE_OFFSET + 24 * 60 + intervalMinutes

        val alarmIntent = Intent(context, FlashLangAlarmReceiver::class.java).apply {
            putExtra(EXTRA_MODE, FlashLangScheduleMode.INTERVAL.name)
            putExtra(EXTRA_INTERVAL_MINUTES, intervalMinutes)
        }

        scheduleAlarm(
            alarmManager = alarmManager,
            triggerAtMillis = triggerAtMillis,
            pendingIntent = pendingIntentFor(context, requestCode, alarmIntent),
        )

        return requestCode
    }

    private fun scheduleAlarm(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pendingIntent: PendingIntent,
    ) {
        try {
            if (canUseExactAlarms(alarmManager)) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent,
                )
            }
        } catch (securityError: SecurityException) {
            Log.w(TAG, "Exact alarms are unavailable on this watch. Falling back to inexact alarms.", securityError)
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
        }
    }

    private fun canUseExactAlarms(alarmManager: AlarmManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun pendingIntentFor(context: Context, requestCode: Int, intent: Intent): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            pendingIntentFlags(),
        )
    }

    private fun notificationIdForCard(cardId: Int): Int = 1000 + cardId

    private fun persistScheduledTimeCodes(context: Context, requestCodes: List<Int>) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SCHEDULED_TIME_CODES, requestCodes.joinToString(","))
            .apply()
    }

    private fun persistScheduledIntervalCode(context: Context, requestCode: Int?) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .apply {
                if (requestCode == null) {
                    remove(KEY_SCHEDULED_INTERVAL_CODE)
                } else {
                    putInt(KEY_SCHEDULED_INTERVAL_CODE, requestCode)
                }
            }
            .apply()
    }

    private fun readScheduledTimeCodes(context: Context): List<Int> {
        val rawValue = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_SCHEDULED_TIME_CODES, null)
            .orEmpty()

        return rawValue.split(",")
            .mapNotNull { value -> value.toIntOrNull() }
    }

    private fun readScheduledIntervalCode(context: Context): Int? {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return if (preferences.contains(KEY_SCHEDULED_INTERVAL_CODE)) {
            preferences.getInt(KEY_SCHEDULED_INTERVAL_CODE, -1).takeIf { it >= 0 }
        } else {
            null
        }
    }

    private fun parseMinuteOfDay(time: String): Int {
        val parts = time.trim().split(":")
        if (parts.size != 2) return -1
        val hour = parts[0].toIntOrNull() ?: return -1
        val minute = parts[1].toIntOrNull() ?: return -1
        return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else -1
    }

    private fun nextRunForMinuteOfDay(minuteOfDay: Int): LocalDateTime {
        val now = LocalDateTime.now()
        var candidate = now
            .withHour(minuteOfDay / 60)
            .withMinute(minuteOfDay % 60)
            .withSecond(0)
            .withNano(0)

        if (!candidate.isAfter(now)) {
            candidate = candidate.plusDays(1)
        }
        return candidate
    }

    private fun pendingIntentFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }
}
