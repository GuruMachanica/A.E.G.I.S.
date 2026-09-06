import 'dart:math' as math;
import 'dart:typed_data';

/// Pure Dart on-device DSP Acoustic and Voice Analysis Service
/// 100% Edge-based, zero server dependencies.
class LocalAudioAnalysis {
  final double rms;
  final double clippingRatio;
  final double signalQuality;
  final bool isSpeech;
  final double syntheticVoiceScore;

  const LocalAudioAnalysis({
    required this.rms,
    required this.clippingRatio,
    required this.signalQuality,
    required this.isSpeech,
    required this.syntheticVoiceScore,
  });
}

class LocalAudioService {
  /// Analyzes a raw PCM-16 Little-Endian mono audio buffer on-device.
  static LocalAudioAnalysis analyzePcm(Uint8List pcmBytes) {
    if (pcmBytes.length < 2) {
      return const LocalAudioAnalysis(
        rms: 0.0,
        clippingRatio: 0.0,
        signalQuality: 0.0,
        isSpeech: false,
        syntheticVoiceScore: 0.0,
      );
    }

    final byteData = ByteData.sublistView(pcmBytes);
    final sampleCount = pcmBytes.length ~/ 2;

    double sumSquares = 0.0;
    int clipCount = 0;
    int zeroCrossings = 0;
    int previousSample = 0;

    // Split into 10 sub-windows to analyze temporal energy variance
    final subWindowSize = math.max(1, sampleCount ~/ 10);
    final subRmsValues = <double>[];
    double currentSubSumSq = 0.0;
    int currentSubCount = 0;

    for (int i = 0; i < sampleCount; i++) {
      final sample = byteData.getInt16(i * 2, Endian.little);
      final normalized = sample / 32768.0;

      sumSquares += normalized * normalized;
      currentSubSumSq += normalized * normalized;
      currentSubCount++;

      if (currentSubCount >= subWindowSize) {
        subRmsValues.add(math.sqrt(currentSubSumSq / currentSubCount));
        currentSubSumSq = 0.0;
        currentSubCount = 0;
      }

      if (sample.abs() >= 32000) {
        clipCount++;
      }

      if (i > 0 && ((previousSample >= 0 && sample < 0) || (previousSample < 0 && sample >= 0))) {
        zeroCrossings++;
      }
      previousSample = sample;
    }

    if (currentSubCount > 0) {
      subRmsValues.add(math.sqrt(currentSubSumSq / currentSubCount));
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    final clippingRatio = clipCount / sampleCount;

    // Quality assessment
    final rmsScore = ((rms - 0.005) / 0.06).clamp(0.0, 1.0);
    final clipPenalty = (1.0 - (clippingRatio * 6.0)).clamp(0.0, 1.0);
    final signalQuality = (rmsScore * 0.7 + clipPenalty * 0.3).clamp(0.0, 1.0);

    // Voice Activity Detection (VAD)
    // Human speech typically has RMS > 0.012 and zero-crossing rate between 0.8% and 45% (85Hz - 3600Hz)
    final zcr = zeroCrossings / sampleCount;
    final isSpeech = rms > 0.012 && zcr >= 0.008 && zcr <= 0.45;

    // Synthetic Voice & Deepfake detection heuristic:
    // Natural human voice has dynamic prosodic variation across syllables (RMS variance > 0.0004).
    // TTS/vocoders often produce unnaturally uniform energy envelopes or excessive high-frequency clipping.
    double syntheticScore = 0.0;
    if (isSpeech && subRmsValues.length >= 4) {
      final meanSubRms = subRmsValues.reduce((a, b) => a + b) / subRmsValues.length;
      double subVariance = 0.0;
      for (final val in subRmsValues) {
        final diff = val - meanSubRms;
        subVariance += diff * diff;
      }
      subVariance /= subRmsValues.length;

      // Low variance during sustained speech indicates robotic or synthetic vocoder flatness
      if (subVariance < 0.00015 && rms > 0.03) {
        syntheticScore = 0.75 + (0.00015 - subVariance) * 1000.0;
      } else if (subVariance < 0.0004 && rms > 0.02) {
        syntheticScore = 0.45 + (0.0004 - subVariance) * 500.0;
      } else {
        // Natural human dynamic range
        syntheticScore = 0.08 + (clippingRatio * 0.4);
      }
    } else if (isSpeech) {
      syntheticScore = 0.12;
    } else {
      syntheticScore = 0.0;
    }

    return LocalAudioAnalysis(
      rms: rms,
      clippingRatio: clippingRatio,
      signalQuality: signalQuality,
      isSpeech: isSpeech,
      syntheticVoiceScore: syntheticScore.clamp(0.0, 0.95),
    );
  }
}
