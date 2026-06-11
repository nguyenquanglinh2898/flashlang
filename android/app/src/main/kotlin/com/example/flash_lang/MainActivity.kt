package com.example.flash_lang

import android.content.pm.PackageManager
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val wearSyncChannelName = "flash_lang_wear_sync"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wearSyncChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWatchDevice" -> {
                        result.success(
                            packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH),
                        )
                    }

                    "syncSnapshot" -> {
                        val snapshotJson = call.argument<String>("snapshotJson")
                        if (snapshotJson.isNullOrBlank()) {
                            result.error("INVALID_SNAPSHOT", "Snapshot JSON is empty.", null)
                            return@setMethodCallHandler
                        }

                        val request = PutDataMapRequest.create("/flashlang/snapshot")
                        request.dataMap.putString("snapshotJson", snapshotJson)
                        request.dataMap.putLong("syncedAt", System.currentTimeMillis())

                        Wearable.getDataClient(this)
                            .putDataItem(request.asPutDataRequest())
                            .addOnSuccessListener {
                                result.success(true)
                            }
                            .addOnFailureListener { error ->
                                Log.e("FlashLangSync", "Failed to sync snapshot", error)
                                result.error(
                                    "SYNC_FAILED",
                                    error.message ?: "Failed to sync snapshot to Wear OS.",
                                    null,
                                )
                            }
                    }

                    "pushCardNotification" -> {
                        val cardId = call.argument<Int>("cardId")
                        val title = call.argument<String>("title")
                        val meaning = call.argument<String>("meaning")

                        if (cardId == null || title.isNullOrBlank() || meaning.isNullOrBlank()) {
                            result.error("INVALID_NOTIFICATION", "Notification payload is incomplete.", null)
                            return@setMethodCallHandler
                        }

                        val request = PutDataMapRequest.create("/flashlang/notification/$cardId/${System.currentTimeMillis()}")
                        request.dataMap.putInt("cardId", cardId)
                        request.dataMap.putString("title", title)
                        request.dataMap.putString("meaning", meaning)
                        request.dataMap.putLong("sentAt", System.currentTimeMillis())

                        Wearable.getDataClient(this)
                            .putDataItem(request.asPutDataRequest())
                            .addOnSuccessListener {
                                result.success(true)
                            }
                            .addOnFailureListener { error ->
                                Log.e("FlashLangSync", "Failed to send watch notification", error)
                                result.error(
                                    "WATCH_NOTIFICATION_FAILED",
                                    error.message ?: "Failed to send notification to Wear OS.",
                                    null,
                                )
                            }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
