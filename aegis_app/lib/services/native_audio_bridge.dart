import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAudioMetrics {
  final double rms;
  final double clipping;
  final double zcr;
  final bool isSpeech;
  final double syntheticScore;
  final double db;

  const NativeAudioMetrics({
    required this.rms,
    required this.clipping,
    required this.zcr,
    required this.isSpeech,
    required this.syntheticScore,
    required this.db,
  });

  factory NativeAudioMetrics.fromMap(Map<dynamic, dynamic> map) {
    return NativeAudioMetrics(
      rms: (map['rms'] as num?)?.toDouble() ?? 0.0,
      clipping: (map['clipping'] as num?)?.toDouble() ?? 0.0,
      zcr: (map['zcr'] as num?)?.toDouble() ?? 0.0,
      isSpeech: map['isSpeech'] == true,
      syntheticScore: (map['syntheticScore'] as num?)?.toDouble() ?? 0.0,
      db: (map['db'] as num?)?.toDouble() ?? -60.0,
    );
  }
}

class NativeAudioBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.aegis_app/native_audio');
  static const EventChannel _eventChannel =
      EventChannel('com.example.aegis_app/audio_stream');

  static bool _isAvailable = false;
  static bool _checked = false;

  static Future<bool> isAvailable() async {
    if (_checked) return _isAvailable;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _isAvailable = false;
      _checked = true;
      return false;
    }
    try {
      final res = await _methodChannel.invokeMethod<bool>('isNativeAvailable');
      _isAvailable = res == true;
    } catch (_) {
      _isAvailable = false;
    }
    _checked = true;
    return _isAvailable;
  }

  static Future<bool> start({int sampleRate = 16000}) async {
    final avail = await isAvailable();
    if (!avail) return false;
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'startAudioRecording',
        {'sampleRate': sampleRate},
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    final avail = await isAvailable();
    if (!avail) return;
    try {
      await _methodChannel.invokeMethod('stopAudioRecording');
    } catch (_) {}
  }

  static Stream<NativeAudioMetrics> get metricsStream {
    return _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((event) => NativeAudioMetrics.fromMap(event as Map));
  }
}
