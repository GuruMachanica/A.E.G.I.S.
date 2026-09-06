import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis_app/services/local_audio_service.dart';
import 'package:aegis_app/services/local_phone_lookup.dart';

void main() {
  group('LocalAudioService tests', () {
    test('handles empty audio gracefully', () {
      final analysis = LocalAudioService.analyzePcm(Uint8List(0));
      expect(analysis.rms, equals(0.0));
      expect(analysis.isSpeech, isFalse);
    });

    test('analyzes synthetic / tone waveform and computes RMS', () {
      // 16000 samples = 1 second at 16kHz
      final pcm = Uint8List(32000);
      final byteData = ByteData.sublistView(pcm);
      for (int i = 0; i < 16000; i++) {
        // 200 Hz vocal fundamental frequency synthetic tone
        final val = (20000 * (i % 80 < 40 ? 1 : -1)).toInt();
        byteData.setInt16(i * 2, val, Endian.little);
      }

      final analysis = LocalAudioService.analyzePcm(pcm);
      expect(analysis.rms, greaterThan(0.5));
      expect(analysis.isSpeech, isTrue);
      expect(analysis.syntheticVoiceScore, greaterThan(0.5));
    });
  });

  group('LocalPhoneLookupService tests', () {
    test('flags suspicious international callback traps', () {
      final res = LocalPhoneLookupService.analyze('+18765551234');
      expect(res.riskLevel, equals('DANGER'));
      expect(res.spamScore, greaterThanOrEqualTo(0.85));
      expect(res.tags, contains('high_risk_country_code'));
    });

    test('flags unregistered telemarketer patterns (+91 140/141)', () {
      final res = LocalPhoneLookupService.analyze('+911401234567');
      expect(res.riskLevel, equals('DANGER'));
      expect(res.tags, contains('telemarketer_or_spoof_pattern'));
    });

    test('passes standard clean mobile numbers', () {
      final res = LocalPhoneLookupService.analyze('+919876543210');
      expect(res.riskLevel, equals('SAFE'));
      expect(res.spamScore, lessThan(0.35));
      expect(res.tags, contains('clean_reputation'));
    });
  });
}
