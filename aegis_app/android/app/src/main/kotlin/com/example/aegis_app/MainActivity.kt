package com.example.aegis_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val nativeAudioEngine = AegisNativeAudioEngine()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register MethodChannel for command invocations
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.aegis_app/native_audio"
        ).setMethodCallHandler(nativeAudioEngine)

        // Register EventChannel for real-time acoustic telemetry streaming
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.aegis_app/audio_stream"
        ).setStreamHandler(nativeAudioEngine)
    }

    override fun onDestroy() {
        nativeAudioEngine.stopRecording()
        super.onDestroy()
    }
}
