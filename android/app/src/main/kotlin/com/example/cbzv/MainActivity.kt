package com.example.cbzv

import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "cbzv/volume"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "handleVolumeKey" -> {
                    val direction = call.arguments as String
                    if (direction == "up") {
                        result.success("Volume Up Pressed")
                    } else if (direction == "down") {
                        result.success("Volume Down Pressed")
                    } else {
                        result.error("INVALID_DIRECTION", "Invalid direction: $direction", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("handleVolumeKey", "up")
                true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("handleVolumeKey", "down")
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
}
