import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';

class LiveRiskScores {
  final double syntheticVoice;
  final double scamIntent;
  final double overall;
  final String transcript;
  final List<String> detectedKeywords;
  final bool sensitiveAlert;
  final String riskLevel;
  final String? scamAlertType;
  final String? scamAlertMessage;
  final bool scamAlertActive;

  const LiveRiskScores({
    required this.syntheticVoice,
    required this.scamIntent,
    required this.overall,
    this.transcript = '',
    this.detectedKeywords = const [],
    this.sensitiveAlert = false,
    this.riskLevel = 'safe',
    this.scamAlertType,
    this.scamAlertMessage,
    this.scamAlertActive = false,
  });
}

class LiveCallService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final http.Client _httpClient = http.Client();
  final StreamController<Uint8List> _audioChunks =
      StreamController<Uint8List>.broadcast();

  /// Header to bypass ngrok free-tier interstitial warning page.
  static const _ngrokHeader = {'ngrok-skip-browser-warning': 'true'};

  WebSocketChannel? _sttChannel;
  StreamSubscription? _sttSub;
  StreamSubscription? _audioSub;
  Timer? _audioWatchdog;
  Timer? _chunkRateTicker;
  Timer? _pollTimer;

  bool _started = false;
  int _chunkCount = 0;
  int _chunksInCurrentSecond = 0;
  int _selectedSampleRate = 16000;
  String? _callId;
  String _lastTranscriptSent = '';
  List<String> _sttUrlCandidates = const [];
  int _sttCandidateIndex = 0;
  List<String> _apiBaseCandidates = const [];
  int _apiBaseIndex = 0;
  bool _chunkUploadInFlight = false;
  bool _sttConnected = false;
  bool _allowSttReconnect = false;
  int _sttReconnectAttempts = 0;
  static const int _maxSttReconnectAttempts = 3;

  void Function(LiveRiskScores scores)? _onRisk;
  void Function(String message)? _onError;

  Uri _uri(String path, [Map<String, String>? query]) {
    final chosenBase = _apiBaseCandidates.isNotEmpty
        ? _apiBaseCandidates[_apiBaseIndex % _apiBaseCandidates.length]
        : backendBaseUrl;
    final base = Uri.parse(chosenBase);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: query,
    );
  }

  List<String> _buildApiBaseCandidates() {
    final urls = <String>[];
    final configured = backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      urls.add(configured);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (!urls.contains('http://127.0.0.1:8000')) {
        urls.add('http://127.0.0.1:8000');
      }
      if (!urls.contains('http://10.0.2.2:8000')) {
        urls.add('http://10.0.2.2:8000');
      }
    }
    if (urls.isEmpty) {
      urls.add('http://127.0.0.1:8000');
    }
    return urls;
  }

  List<String> _buildSttUrlCandidates() {
    final urls = <String>[];
    final configured = sttWsUrl.trim();
    final configuredLower = configured.toLowerCase();
    if (configured.isNotEmpty) {
      urls.add(configured);
    }

    final isLocalConfigured =
        configured.isEmpty ||
        configuredLower.contains('127.0.0.1') ||
        configuredLower.contains('localhost') ||
        configuredLower.contains('10.0.2.2');

    if (isLocalConfigured) {
      if (!urls.contains('ws://127.0.0.1:8002/asr')) {
        urls.add('ws://127.0.0.1:8002/asr');
      }
      if (!urls.contains('ws://10.0.2.2:8002/asr')) {
        urls.add('ws://10.0.2.2:8002/asr');
      }
    }
    return urls;
  }

  double _localIntentHint(String text) {
    final lowered = text.toLowerCase();
    final patterns = <RegExp>[
      RegExp(r'\botp\b'),
      RegExp(r'\bpin\b'),
      RegExp(r'\bcvv\b'),
      RegExp(r'password'),
      RegExp(r'kyc'),
      RegExp(r'bank|account|ifsc'),
      RegExp(r'money|transfer|send money|paisa|paise|rupay|rupaye'),
      RegExp(r'पैसे|रुपये|रकम|भेजो|ओटीपी|otp'),
      RegExp(r'urgent|immediate|अभी|तुरंत'),
    ];

    var hits = 0;
    for (final pattern in patterns) {
      if (pattern.hasMatch(lowered)) {
        hits += 1;
      }
    }
    if (hits == 0) return 0.0;

    final hasOtp = RegExp(r'\botp\b|ओटीपी|verification').hasMatch(lowered);
    final hasMoney = RegExp(
      r'money|transfer|paisa|paise|रुपये|पैसे|रकम|भेजो',
    ).hasMatch(lowered);
    if (hasOtp && hasMoney) {
      return 0.92;
    }
    return (hits * 0.16).clamp(0.0, 0.85);
  }

  Future<int> _startRecorderWithFallback() async {
    final sampleRates = <int>[16000, 44100];
    Object? lastError;

    for (final sampleRate in sampleRates) {
      try {
        await _recorder.startRecorder(
          codec: Codec.pcm16,
          sampleRate: sampleRate,
          numChannels: 1,
          bitRate: sampleRate,
          bufferSize: 8192,
          toStream: _audioChunks.sink,
        );
        await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 200),
        );
        return sampleRate;
      } catch (error) {
        lastError = error;
        try {
          await _recorder.stopRecorder();
        } catch (_) {}
      }
    }

    throw Exception(
      'Unable to start recorder on supported sample rates: $lastError',
    );
  }

  Future<void> _startSession(String callNumber) async {
    Object? lastError;
    for (var attempt = 0; attempt < _apiBaseCandidates.length; attempt++) {
      _apiBaseIndex = attempt;
      try {
        final response = await _httpClient
            .post(
              _uri('/assist/live-audio/session/start'),
              headers: {'Content-Type': 'application/json', ..._ngrokHeader},
              body: jsonEncode({'call_number': callNumber}),
            )
            .timeout(networkTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final callId = decoded['call_id']?.toString();
        if (callId == null || callId.isEmpty) {
          lastError = 'Invalid live session response.';
          continue;
        }

        _callId = callId;
        return;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Failed to start live session: $lastError');
  }

  Future<void> _sendTranscript(String text) async {
    final callId = _callId;
    if (callId == null || text.trim().isEmpty) return;

    try {
      final trimmed = text.trim();
      await _httpClient
          .post(
            _uri('/assist/live-audio/transcript', {'call_id': callId}),
            headers: {'Content-Type': 'application/json', ..._ngrokHeader},
            body: jsonEncode({
              'text': trimmed,
              'client_intent_score': _localIntentHint(trimmed),
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      _onError?.call('Transcript upload failed: $e');
    }
  }

  Future<void> _sendAudioChunk(Uint8List frame) async {
    final callId = _callId;
    if (callId == null || frame.isEmpty) return;
    if (_chunkUploadInFlight) return;

    _chunkUploadInFlight = true;
    try {
      final response = await _httpClient
          .post(
            _uri('/assist/live-audio/chunk', {
              'call_id': callId,
              'sample_rate': '$_selectedSampleRate',
              'channels': '1',
            }),
            headers: {'Content-Type': 'application/octet-stream', ..._ngrokHeader},
            body: frame,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _onError?.call('Chunk upload failed (${response.statusCode}).');
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final analysis = decoded['analysis'];
      if (analysis is Map<String, dynamic>) {
        _emitRisk(analysis);
      }
    } catch (e) {
      _onError?.call('Audio upload error: $e');
    } finally {
      _chunkUploadInFlight = false;
    }
  }

  Future<void> _pollLatestState() async {
    final callId = _callId;
    if (callId == null) return;
    if (_chunkUploadInFlight) return;

    try {
      final response = await _httpClient
          .get(_uri('/assist/live-audio/state/$callId'), headers: _ngrokHeader)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final analysis = decoded['analysis'];
      if (analysis is Map<String, dynamic>) {
        _emitRisk(analysis);
      }
    } catch (_) {}
  }

  void _emitRisk(Map<String, dynamic> decoded) {
    if (_onRisk == null) return;
    final synthetic =
        (decoded['synthetic_voice_score'] as num?)?.toDouble() ?? 0.0;
    final scam = (decoded['scam_intent_score'] as num?)?.toDouble() ?? 0.0;
    final overall =
        (decoded['overall_score'] as num?)?.toDouble() ??
        ((synthetic + scam) / 2);
    final transcript = decoded['transcript']?.toString() ?? '';
    final resolvedTranscript = transcript.trim().isNotEmpty
        ? transcript
        : _lastTranscriptSent;
    final keywords =
        (decoded['detected_keywords'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final sensitiveAlert = decoded['sensitive_alert'] == true;
    final riskLevel = (decoded['risk_level']?.toString() ?? 'safe')
        .toLowerCase();

    _onRisk!.call(
      LiveRiskScores(
        syntheticVoice: synthetic.clamp(0.0, 1.0),
        scamIntent: scam.clamp(0.0, 1.0),
        overall: overall.clamp(0.0, 1.0),
        transcript: resolvedTranscript,
        detectedKeywords: keywords,
        sensitiveAlert: sensitiveAlert,
        riskLevel: riskLevel,
        scamAlertType: decoded['scam_alert_type']?.toString(),
        scamAlertMessage: decoded['scam_alert_message']?.toString(),
        scamAlertActive: decoded['scam_alert_active'] == true,
      ),
    );
  }

  void _connectSttWebSocket() {
    if (_sttUrlCandidates.isEmpty) {
      _sttUrlCandidates = _buildSttUrlCandidates();
      _sttCandidateIndex = 0;
    }
    final target =
        _sttUrlCandidates[_sttCandidateIndex % _sttUrlCandidates.length];

    try {
      _sttChannel = WebSocketChannel.connect(Uri.parse(target));
      _sttConnected = true;
      _sttSub?.cancel();
      _sttSub = _sttChannel!.stream.listen(
        (event) {
          try {
            if (event is! String) return;
            final decoded = jsonDecode(event) as Map<String, dynamic>;

            String merged = '';
            final lines = decoded['lines'];
            if (lines is List) {
              merged = lines
                  .whereType<Map>()
                  .map((line) => (line['text'] ?? '').toString().trim())
                  .where((text) => text.isNotEmpty)
                  .join(' ')
                  .trim();
            }

            if (merged.isEmpty) {
              merged = decoded['buffer_transcription']?.toString().trim() ?? '';
            }

            if (merged.isEmpty || merged == _lastTranscriptSent) {
              return;
            }

            _lastTranscriptSent = merged;
            _sendTranscript(merged);
          } catch (_) {}
        },
        onError: (_) {
          _sttConnected = false;
          _sttReconnectAttempts++;
          if (!_allowSttReconnect ||
              _sttReconnectAttempts > _maxSttReconnectAttempts * _sttUrlCandidates.length) {
            return;
          }
          _sttCandidateIndex =
              (_sttCandidateIndex + 1) % _sttUrlCandidates.length;
          Future<void>.delayed(
            const Duration(seconds: 5),
            _connectSttWebSocket,
          );
        },
        onDone: () {
          _sttConnected = false;
          _sttReconnectAttempts++;
          if (!_allowSttReconnect ||
              _sttReconnectAttempts > _maxSttReconnectAttempts * _sttUrlCandidates.length) {
            return;
          }
          _sttCandidateIndex =
              (_sttCandidateIndex + 1) % _sttUrlCandidates.length;
          Future<void>.delayed(
            const Duration(seconds: 5),
            _connectSttWebSocket,
          );
        },
      );
    } catch (_) {
      _sttConnected = false;
      _sttReconnectAttempts++;
      if (!_allowSttReconnect ||
          _sttReconnectAttempts > _maxSttReconnectAttempts * _sttUrlCandidates.length) {
        return;
      }
      _sttCandidateIndex = (_sttCandidateIndex + 1) % _sttUrlCandidates.length;
      Future<void>.delayed(
        const Duration(seconds: 5),
        _connectSttWebSocket,
      );
    }
  }

  Future<void> start({
    required String callNumber,
    required void Function(LiveRiskScores scores) onRisk,
    required void Function(String message) onError,
    void Function(int chunksPerSecond, int sampleRate)? onAudioDebug,
  }) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw Exception('Microphone permission denied.');
    }

    _onRisk = onRisk;
    _onError = onError;

    try {
      _apiBaseCandidates = _buildApiBaseCandidates();
      _apiBaseIndex = 0;
      await _startSession(callNumber);
      await _recorder.openRecorder();
      _selectedSampleRate = await _startRecorderWithFallback();

      _sttUrlCandidates = _buildSttUrlCandidates();
      _sttCandidateIndex = 0;
      _allowSttReconnect = true;
      _connectSttWebSocket();

      final audioBatch = <int>[];
      _audioSub = _audioChunks.stream.listen((bytes) {
        if (bytes.isEmpty) return;
        _chunkCount += 1;
        _chunksInCurrentSecond += 1;

        audioBatch.addAll(bytes);
        if (audioBatch.length >= 32000) {
          final frame = Uint8List.fromList(audioBatch);
          _sendAudioChunk(frame);
          if (_sttConnected &&
              _sttChannel != null &&
              _sttChannel!.closeCode == null) {
            try {
              _sttChannel!.sink.add(frame);
            } catch (_) {
              _sttConnected = false;
              if (_allowSttReconnect) {
                Future<void>.delayed(
                  const Duration(milliseconds: 800),
                  _connectSttWebSocket,
                );
              }
            }
          }
          audioBatch.clear();
        }
      }, onError: (e) => onError('Audio stream error: $e'));

      _chunkRateTicker?.cancel();
      _chunkRateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        final chunks = _chunksInCurrentSecond;
        _chunksInCurrentSecond = 0;
        onAudioDebug?.call(chunks, _selectedSampleRate);
      });

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _pollLatestState();
      });

      _audioWatchdog?.cancel();
      _audioWatchdog = Timer(const Duration(seconds: 4), () {
        if (_chunkCount == 0) {
          onError(
            'Microphone stream inactive. On emulator, enable host mic in Extended Controls > Microphone.',
          );
        }
      });

      _started = true;
    } catch (e) {
      await stop();
      throw Exception('Unable to start call monitor: $e');
    }
  }

  Future<void> stop() async {
    if (_started) {
      await _recorder.stopRecorder();
    }

    _audioWatchdog?.cancel();
    _audioWatchdog = null;
    _chunkRateTicker?.cancel();
    _chunkRateTicker = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    _chunkCount = 0;
    _chunksInCurrentSecond = 0;

    _started = false;
    await _audioSub?.cancel();
    await _sttSub?.cancel();
    _audioSub = null;
    _sttSub = null;

    await _sttChannel?.sink.close();
    _sttChannel = null;

    _callId = null;
    _onRisk = null;
    _onError = null;
    _lastTranscriptSent = '';
    _sttUrlCandidates = const [];
    _sttCandidateIndex = 0;
    _apiBaseCandidates = const [];
    _apiBaseIndex = 0;
    _chunkUploadInFlight = false;
    _sttConnected = false;
    _allowSttReconnect = false;

    await _recorder.closeRecorder();
  }

  Future<void> dispose() async {
    await stop();
    await _audioChunks.close();
    _httpClient.close();
  }
}

final liveCallServiceProvider = Provider<LiveCallService>((ref) {
  final service = LiveCallService();
  ref.onDispose(service.dispose);
  return service;
});
