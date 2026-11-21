package com.i_nnova.eride

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val liveTripNotificationChannel = "com.i_nnova.eride/live_trip_notification"

    override fun onCreate(savedInstanceState: Bundle?) {
        // A link that opened the app once must not open again when Android recreates the
        // activity (process killed, app updated, reopened from recents): drop it before
        // Flutter reads the launch link.
        val fromHistory = ((intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if ((savedInstanceState != null || fromHistory) && intent?.action == Intent.ACTION_VIEW) {
            intent = Intent(intent).setData(null).setAction(Intent.ACTION_MAIN)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, liveTripNotificationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOrUpdate" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data != null) {
                            LiveTripNotificationManager.showOrUpdate(applicationContext, data)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        LiveTripNotificationManager.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
