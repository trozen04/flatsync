package com.trozen.flatsync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Start background service after boot
            val flutterEngine = FlutterEngine(context)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "background_service")
            channel.invokeMethod("startService", null)
        }
    }
}