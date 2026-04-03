import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../services/live_call_service.dart';

class CallMonitorState {
  final bool isMonitoring;
  final bool isConnecting;
  final String activeCallNumber;
  final double overallFraudScore;
  final double syntheticVoiceScore;
  final double scamChanceScore;
  final bool isMuted;
  final bool isFlagged;
  final bool callEnded;
  final String? errorMessage;
  final String? transcript;
  final List<String>? detectedKeywords;
  final bool showSensitiveAlert;
  final String? riskLevel;
  final int? audioChunksPerSecond;
  final int? recorderSampleRate;
  final String? scamAlertType;
  final String? scamAlertMessage;
  final bool scamAlertActive;

  const CallMonitorState({
    this.isMonitoring = false,
    this.isConnecting = false,
    this.activeCallNumber = '',
    this.overallFraudScore = 0.0,
    this.syntheticVoiceScore = 0.0,
    this.scamChanceScore = 0.0,
    this.isMuted = false,
    this.isFlagged = false,
    this.callEnded = false,
    this.errorMessage,
    this.transcript = '',
    this.detectedKeywords = const [],
    this.showSensitiveAlert = false,
    this.riskLevel = 'safe',
    this.audioChunksPerSecond = 0,
    this.recorderSampleRate = 0,
    this.scamAlertType,
    this.scamAlertMessage,
    this.scamAlertActive = false,
  });

  bool get isHighRisk => overallFraudScore >= 0.65;
  String get safeTranscript => transcript ?? '';
  List<String> get safeDetectedKeywords => detectedKeywords ?? const [];
  String get safeRiskLevel {
    final value = riskLevel;
    if (value == null || value.trim().isEmpty) return 'safe';
    return value;
  }

  int get safeAudioChunksPerSecond => audioChunksPerSecond ?? 0;
  int get safeRecorderSampleRate => recorderSampleRate ?? 0;

  CallMonitorState copyWith({
    bool? isMonitoring,
    bool? isConnecting,
    String? activeCallNumber,
    double? overallFraudScore,
    double? syntheticVoiceScore,
    double? scamChanceScore,
    bool? isMuted,
    bool? isFlagged,
    bool? callEnded,
    String? errorMessage,
    String? transcript,
    List<String>? detectedKeywords,
    bool? showSensitiveAlert,
    String? riskLevel,
    int? audioChunksPerSecond,
    int? recorderSampleRate,
    String? scamAlertType,
    String? scamAlertMessage,
    bool? scamAlertActive,
    bool clearError = false,
    bool clearScamAlert = false,
  }) {
    return CallMonitorState(
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isConnecting: isConnecting ?? this.isConnecting,
      activeCallNumber: activeCallNumber ?? this.activeCallNumber,
      overallFraudScore: overallFraudScore ?? this.overallFraudScore,
      syntheticVoiceScore: syntheticVoiceScore ?? this.syntheticVoiceScore,
      scamChanceScore: scamChanceScore ?? this.scamChanceScore,
      isMuted: isMuted ?? this.isMuted,
      isFlagged: isFlagged ?? this.isFlagged,
      callEnded: callEnded ?? this.callEnded,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      transcript: transcript ?? this.transcript ?? '',
      detectedKeywords: detectedKeywords ?? this.detectedKeywords ?? const [],
      showSensitiveAlert: showSensitiveAlert ?? this.showSensitiveAlert,
      riskLevel: riskLevel ?? this.riskLevel ?? 'safe',
      audioChunksPerSecond:
          audioChunksPerSecond ?? this.audioChunksPerSecond ?? 0,
      recorderSampleRate: recorderSampleRate ?? this.recorderSampleRate ?? 0,
      scamAlertType: clearScamAlert
          ? null
          : (scamAlertType ?? this.scamAlertType),
      scamAlertMessage: clearScamAlert
          ? null
          : (scamAlertMessage ?? this.scamAlertMessage),
      scamAlertActive: clearScamAlert
          ? false
          : (scamAlertActive ?? this.scamAlertActive),
    );
  }
}

class CallMonitorNotifier extends Notifier<CallMonitorState> {
  bool _vibratedForCurrentThreat = false;
  Timer? _reconnectTimer;
  Timer? _keywordAlertTimer;

  @override
  CallMonitorState build() {
    ref.onDispose(() async {
      _reconnectTimer?.cancel();
      _keywordAlertTimer?.cancel();
      await ref.read(liveCallServiceProvider).stop();
    });
    return const CallMonitorState();
  }

  Future<void> startMonitoring(String callNumber) async {
    if (state.isMonitoring || state.isConnecting) return;

    _vibratedForCurrentThreat = false;
    state = state.copyWith(
      isConnecting: true,
      activeCallNumber: callNumber,
      callEnded: false,
      clearError: true,
      overallFraudScore: 0.0,
      syntheticVoiceScore: 0.0,
      scamChanceScore: 0.0,
      transcript: '',
      detectedKeywords: const [],
      showSensitiveAlert: false,
      riskLevel: 'safe',
      audioChunksPerSecond: 0,
      recorderSampleRate: 0,
      clearScamAlert: true,
    );

    try {
      await ref
          .read(liveCallServiceProvider)
          .start(
            callNumber: callNumber,
            onRisk: (scores) {
              final bool showAlert =
                  scores.sensitiveAlert && scores.detectedKeywords.isNotEmpty;
              state = state.copyWith(
                isMonitoring: true,
                isConnecting: false,
                overallFraudScore: scores.overall,
                syntheticVoiceScore: scores.syntheticVoice,
                scamChanceScore: scores.scamIntent,
                transcript: scores.transcript,
                detectedKeywords: scores.detectedKeywords,
                showSensitiveAlert: showAlert,
                riskLevel: scores.riskLevel,
                scamAlertType: scores.scamAlertType,
                scamAlertMessage: scores.scamAlertMessage,
                scamAlertActive: scores.scamAlertActive,
              );
              if (showAlert) {
                _keywordAlertTimer?.cancel();
                _keywordAlertTimer = Timer(const Duration(seconds: 8), () {
                  if (!ref.mounted) return;
                  state = state.copyWith(showSensitiveAlert: false);
                });
              }
              _triggerHapticIfNeeded();
            },
            onError: (message) {
              final lowered = message.toLowerCase();
              final shouldReconnect =
                  lowered.contains('closed') || lowered.contains('network');
              state = state.copyWith(
                errorMessage: message,
                isMonitoring: shouldReconnect ? false : state.isMonitoring,
                isConnecting: shouldReconnect ? false : state.isConnecting,
              );
              if (shouldReconnect) {
                _scheduleReconnect();
              }
            },
            onAudioDebug: (chunksPerSecond, sampleRate) {
              state = state.copyWith(
                audioChunksPerSecond: chunksPerSecond,
                recorderSampleRate: sampleRate,
              );
            },
          );

      state = state.copyWith(
        isMonitoring: true,
        isConnecting: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isMonitoring: false,
        isConnecting: false,
        errorMessage: e.toString(),
      );
    }
  }

  void updateScores({
    required double syntheticVoice,
    required double scamChance,
  }) {
    final overall = (syntheticVoice * 0.5 + scamChance * 0.5).clamp(0.0, 1.0);
    state = state.copyWith(
      syntheticVoiceScore: syntheticVoice,
      scamChanceScore: scamChance,
      overallFraudScore: overall,
    );
    _triggerHapticIfNeeded();
  }

  Future<void> _triggerHapticIfNeeded() async {
    if (!state.isHighRisk || state.isMuted || _vibratedForCurrentThreat) return;

    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: [0, 250, 180, 250]);
      _vibratedForCurrentThreat = true;
    }
  }

  void muteAlert() => state = state.copyWith(isMuted: !state.isMuted);

  void flagCall() => state = state.copyWith(isFlagged: true);

  Future<void> endCall() async {
    _reconnectTimer?.cancel();
    _keywordAlertTimer?.cancel();
    await ref.read(liveCallServiceProvider).stop();
    state = state.copyWith(
      isMonitoring: false,
      isConnecting: false,
      callEnded: true,
      showSensitiveAlert: false,
      audioChunksPerSecond: 0,
      recorderSampleRate: 0,
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  void dismissScamAlert() => state = state.copyWith(clearScamAlert: true);

  void _scheduleReconnect() {
    if (state.activeCallNumber.isEmpty || state.callEnded) return;
    final callNumber = state.activeCallNumber;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (!ref.mounted || state.callEnded) return;
      state = state.copyWith(isMonitoring: false, isConnecting: false);
      await ref.read(liveCallServiceProvider).stop();
      if (!ref.mounted || state.callEnded) return;
      await startMonitoring(callNumber);
    });
  }
}

final callMonitorProvider =
    NotifierProvider<CallMonitorNotifier, CallMonitorState>(
      CallMonitorNotifier.new,
    );
