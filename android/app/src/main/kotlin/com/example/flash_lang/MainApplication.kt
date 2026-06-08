package com.example.flash_lang

import android.util.Log
import androidx.work.Configuration
import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.INFO)
            .build()
}
