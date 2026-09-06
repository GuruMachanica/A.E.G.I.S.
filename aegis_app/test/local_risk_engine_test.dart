import 'package:aegis_app/services/local_risk_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalRiskEngine on-device threat tests', () {
    test('returns 0 score for safe conversation', () {
      final res = LocalRiskEngine.evaluate('Hello, how are you doing today?');
      expect(res.intentScore, 0.0);
      expect(res.detectedKeywords, isEmpty);
      expect(res.primaryAlert, isNull);
    });

    test('detects OTP extortion with high threat score', () {
      final res = LocalRiskEngine.evaluate(
          'Please read me the 6 digit OTP you received right now');
      expect(res.intentScore, greaterThanOrEqualTo(0.85));
      expect(res.detectedKeywords, contains('otp_threat'));
      expect(res.primaryAlert, isNotNull);
    });

    test('detects Digital Arrest and police threat in Hindi and English', () {
      final res = LocalRiskEngine.evaluate(
          'This is CBI digital arrest officer. Your account is freeze.');
      expect(res.intentScore, greaterThanOrEqualTo(0.85));
      expect(res.detectedKeywords, contains('digital_arrest'));
    });
  });
}
