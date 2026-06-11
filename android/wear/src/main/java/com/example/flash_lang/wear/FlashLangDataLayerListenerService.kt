package com.example.flash_lang.wear

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

class FlashLangDataLayerListenerService : WearableListenerService() {
    companion object {
        private const val TAG = "FlashLangWearSync"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        super.onDataChanged(dataEvents)

        for (index in 0 until dataEvents.count) {
            val event = dataEvents.get(index)
            val dataItem = event.dataItem
            val path = dataItem.uri.path ?: continue
            val dataMap = DataMapItem.fromDataItem(dataItem).dataMap

            try {
                when {
                    path == "/flashlang/snapshot" -> {
                        val snapshotJson = dataMap.getString("snapshotJson") ?: continue
                        FlashLangSnapshotStore.saveSnapshotJson(applicationContext, snapshotJson)
                        FlashLangNotificationScheduler.reschedule(applicationContext)
                        sendBroadcast(Intent(FlashLangSyncEvents.ACTION_SNAPSHOT_UPDATED).setPackage(packageName))
                        Log.d(TAG, "Snapshot synced to watch successfully.")
                    }

                    path.startsWith("/flashlang/notification/") -> {
                        val cardId = dataMap.getInt("cardId", -1)
                        val title = dataMap.getString("title").orEmpty()
                        val meaning = dataMap.getString("meaning").orEmpty()
                        if (cardId >= 0 && title.isNotBlank() && meaning.isNotBlank()) {
                            FlashLangNotificationScheduler.showCardNotification(
                                context = applicationContext,
                                cardId = cardId,
                                title = title,
                                meaning = meaning,
                            )
                            Log.d(TAG, "Watch notification shown for cardId=$cardId")
                        }
                    }
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to handle synced data item on watch.", error)
            }
        }
    }
}
