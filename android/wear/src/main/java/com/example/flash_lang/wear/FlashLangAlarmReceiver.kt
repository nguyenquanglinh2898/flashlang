package com.example.flash_lang.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FlashLangAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FlashLangNotificationScheduler.showNextCardNotification(context)
        FlashLangNotificationScheduler.reschedule(context)
    }
}
