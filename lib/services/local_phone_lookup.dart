/// Pure Dart On-Device Phone Threat & Caller ID Intelligence Service
/// 100% Edge-based, zero network requests.
class PhoneThreatResult {
  final String phoneNumber;
  final bool isValid;
  final double spamScore;
  final String riskLevel;
  final List<String> tags;
  final String? warning;

  const PhoneThreatResult({
    required this.phoneNumber,
    required this.isValid,
    required this.spamScore,
    required this.riskLevel,
    required this.tags,
    this.warning,
  });
}

class LocalPhoneLookupService {
  static const Map<String, String> suspiciousPrefixes = {
    '+1876': 'Caribbean Sweepstakes Scam Area Code',
    '+1284': 'BVI Premium Rate Callback Trap',
    '+1473': 'Grenada One-Ring Scam Area Code',
    '+1809': 'Dominican Republic One-Ring Scam',
    '+232': 'Sierra Leone International Robocall Range',
    '+252': 'Somalia One-Ring Callback Range',
    '+92': 'Cross-Border Social Engineering Call Range',
  };

  static final List<RegExp> suspiciousPatterns = [
    RegExp(r'^\+91(?:140|141)\d{7}$'), // Unregistered Indian Telemarketing Ranges
    RegExp(r'^\+?00\d+$'), // Double Zero International Spoofing
    RegExp(r'^\+?[0-9]{1,4}1900\d+$'), // Premium Rate Toll Trap
  ];

  static PhoneThreatResult analyze(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.isEmpty) {
      return PhoneThreatResult(
        phoneNumber: phoneNumber,
        isValid: false,
        spamScore: 0.0,
        riskLevel: 'UNKNOWN',
        tags: const ['invalid_format'],
        warning: 'Phone number is empty or invalid format.',
      );
    }

    final tags = <String>[];
    String? warning;
    double spamScore = 0.0;

    // Check prefix blacklist
    for (final entry in suspiciousPrefixes.entries) {
      if (cleaned.startsWith(entry.key)) {
        tags.add('high_risk_country_code');
        tags.add('one_ring_callback_risk');
        warning = 'High Risk Prefix: ${entry.value}';
        spamScore = 0.85;
        break;
      }
    }

    // Check regex patterns
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(cleaned)) {
        tags.add('telemarketer_or_spoof_pattern');
        warning ??= 'Suspicious caller ID pattern flagged by threat engine.';
        spamScore = spamScore < 0.75 ? 0.75 : spamScore;
        break;
      }
    }

    // Length anomaly
    final digitsOnly = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 15) {
      tags.add('abnormal_length');
      spamScore = spamScore < 0.50 ? 0.50 : spamScore;
    }

    String riskLevel;
    if (spamScore >= 0.70) {
      riskLevel = 'DANGER';
    } else if (spamScore >= 0.35) {
      riskLevel = 'WARNING';
    } else {
      riskLevel = 'SAFE';
      tags.add('clean_reputation');
    }

    return PhoneThreatResult(
      phoneNumber: cleaned,
      isValid: true,
      spamScore: double.parse(spamScore.toStringAsFixed(2)),
      riskLevel: riskLevel,
      tags: tags,
      warning: warning,
    );
  }
}
