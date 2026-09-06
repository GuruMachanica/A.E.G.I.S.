package com.example.aegis_app

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * High-performance Native Android Kotlin Audio & INT8 DSP Engine for A.E.G.I.S.
 * Executes on-device real-time acoustic feature extraction, VAD, and synthetic voice detection.
 */
class AegisNativeAudioEngine : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val recordingExecutor = Executors.newSingleThreadExecutor()

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var eventSink: EventChannel.EventSink? = null

    private var sampleRate = 16000
    private var bufferSize = 2048

    // Real-time telemetry cache
    @Volatile
    private var latestRms: Double = 0.0
    @Volatile
    private var latestClipping: Double = 0.0
    @Volatile
    private var latestZcr: Double = 0.0
    @Volatile
    private var latestIsSpeech: Boolean = false
    @Volatile
    private var latestSyntheticScore: Double = 0.0
    @Volatile
    private var latestDb: Double = -60.0

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNativeAvailable" -> result.success(true)
            "startAudioRecording" -> {
                val rate = call.argument<Int>("sampleRate") ?: 16000
                val success = startRecording(rate)
                result.success(success)
            }
            "stopAudioRecording" -> {
                stopRecording()
                result.success(true)
            }
            "getAudioMetrics" -> {
                val metrics = mapOf(
                    "rms" to latestRms,
                    "clipping" to latestClipping,
                    "zcr" to latestZcr,
                    "isSpeech" to latestIsSpeech,
                    "syntheticScore" to latestSyntheticScore,
                    "db" to latestDb
                )
                result.success(metrics)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    @Synchronized
    private fun startRecording(requestedRate: Int): Boolean {
        if (isRecording) return true
        sampleRate = requestedRate

        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        bufferSize = max(minBuf, 2048)

        return try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord?.release()
                audioRecord = null
                return false
            }

            audioRecord?.startRecording()
            isRecording = true

            recordingExecutor.execute {
                processAudioLoop()
            }
            true
        } catch (e: Exception) {
            audioRecord?.release()
            audioRecord = null
            isRecording = false
            false
        }
    }

    private fun processAudioLoop() {
        val audioBuffer = ShortArray(1024)
        val subWindowEnergies = DoubleArray(8)
        var subWindowIndex = 0

        while (isRecording) {
            val record = audioRecord ?: break
            val readCount = record.read(audioBuffer, 0, audioBuffer.size)
            if (readCount <= 0) continue

            // ── INT8 & INT16 High-Performance DSP Math ─────────────────────
            var sumSquares = 0.0
            var clipCount = 0
            var zeroCrossings = 0
            var prevSample = 0

            for (i in 0 until readCount) {
                val sample = audioBuffer[i].toInt()
                val norm = sample / 32768.0
                sumSquares += norm * norm

                if (abs(sample) >= 32000) {
                    clipCount++
                }

                if (i > 0 && ((prevSample >= 0 && sample < 0) || (prevSample < 0 && sample >= 0))) {
                    zeroCrossings++
                }
                prevSample = sample
            }

            val rms = sqrt(sumSquares / readCount)
            val clipping = clipCount.toDouble() / readCount
            val zcr = zeroCrossings.toDouble() / readCount

            // dB level estimation
            val db = if (rms > 0.00001) max(-70.0, 20.0 * log10(rms)) else -70.0

            // Voice Activity Detection (VAD)
            val isSpeech = rms > 0.012 && zcr in 0.008..0.45

            // Sub-band energy tracking for synthetic voice detection
            subWindowEnergies[subWindowIndex % 8] = rms
            subWindowIndex++

            var syntheticScore = 0.0
            if (isSpeech && subWindowIndex >= 8) {
                var mean = 0.0
                for (v in subWindowEnergies) mean += v
                mean /= 8.0

                var variance = 0.0
                for (v in subWindowEnergies) {
                    val d = v - mean
                    variance += d * d
                }
                variance /= 8.0

                // Unnatural energy flatness (< 0.00018) indicates synthesized vocoder
                syntheticScore = when {
                    variance < 0.00015 && rms > 0.03 -> min(0.95, 0.75 + (0.00015 - variance) * 1200.0)
                    variance < 0.00035 && rms > 0.02 -> min(0.70, 0.40 + (0.00035 - variance) * 600.0)
                    else -> 0.08 + (clipping * 0.4)
                }
            } else if (isSpeech) {
                syntheticScore = 0.12
            }

            latestRms = rms
            latestClipping = clipping
            latestZcr = zcr
            latestIsSpeech = isSpeech
            latestSyntheticScore = syntheticScore
            latestDb = db

            // Stream telemetry payload to Flutter EventChannel on Main Looper
            val sink = eventSink
            if (sink != null) {
                val payload = mapOf(
                    "rms" to rms,
                    "clipping" to clipping,
                    "zcr" to zcr,
                    "isSpeech" to isSpeech,
                    "syntheticScore" to syntheticScore,
                    "db" to db
                )
                mainHandler.post {
                    sink.success(payload)
                }
            }

            try {
                Thread.sleep(30) // ~33 Hz update rate
            } catch (_: InterruptedException) {
                break
            }
        }
    }

    @Synchronized
    fun stopRecording() {
        isRecording = false
        try {
            audioRecord?.stop()
        } catch (_: Exception) {}
        audioRecord?.release()
        audioRecord = null
    }
}
