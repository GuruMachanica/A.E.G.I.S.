/// Local On-Device NLP Scam Threat Engine (Edge / Offline Capable)
/// Evaluates live transcripts in 0ms on-device using regex threat patterns.
library;

class ThreatAlertResult {
  final double intentScore; // 0.0 to 1.0
  final List<String> detectedKeywords;
  final List<String> alerts;
  final String? primaryAlert;
  final String? scamAlertType;
  final String? scamAlertMessage;
  final bool scamAlertActive;

  const ThreatAlertResult({
    required this.intentScore,
    required this.detectedKeywords,
    required this.alerts,
    this.primaryAlert,
    this.scamAlertType,
    this.scamAlertMessage,
    this.scamAlertActive = false,
  });
}

class LocalRiskEngine {
  static const List<(String pattern, String alertTag, String userAlert)>
      rules = [
    (
      r'\botp\b|verification\s*code|ओटीपी|ஓடிபி|ఓటీపీ|ಒಟಿಪಿ',
      'otp_threat',
      '🚨 ALERT: Caller is requesting an OTP or verification code. NEVER share it!'
    ),
    (
      r'\bpin\b|upi\s*pin|पिन',
      'pin_threat',
      '🚨 ALERT: Caller asked for your PIN. Entering a PIN will DEDUCT money!'
    ),
    (
      r'\bcvv\b|card\s*number|credit\s*card|debit\s*card',
      'card_details',
      '⚠️ WARNING: Card numbers or CVV requested. Never disclose card details!'
    ),
    (
      r'bank\s*account|ifsc|खाता|बँक\s*खाते',
      'bank_details',
      '⚠️ WARNING: Bank account details requested. Verify caller identity.'
    ),
    (
      r'digital\s*arrest|cbi|police|customs|पोलीस|கைது|डिजिटल\s*अरेस्ट',
      'digital_arrest',
      '🚨 CRITICAL: Digital Arrest / Police coercion scam detected! Hang up immediately.'
    ),
    (
      r'kyc\s*update|block\s*your\s*account|freeze\s*account|खाता\s*ब्लॉक',
      'kyc_urgency',
      '⚠️ WARNING: KYC freeze threat detected. Official banks do not freeze accounts over call.'
    ),
    (
      r'transfer\s*money|send\s*money|पैसे\s*भेजो|பணம்\s*அனுப்பு|డబ్బులు\s*పంపండి',
      'transfer_request',
      '🚨 DANGER: Urgent money transfer demand detected.'
    ),
    (
      r'lottery|reward\s*claim|jackpot|लॉटरी',
      'lottery_scam',
      '⚠️ WARNING: Lottery claim or prize scam detected.'
    ),
  ];

  /// Evaluates the input transcript and returns risk score and detected alerts.
  static ThreatAlertResult evaluate(String transcript) {
    if (transcript.trim().isEmpty) {
      return const ThreatAlertResult(
        intentScore: 0.0,
        detectedKeywords: [],
        alerts: [],
      );
    }

    final lower = transcript.toLowerCase();
    final detectedKeywords = <String>[];
    final alerts = <String>[];
    String? primaryAlert;

    for (final rule in rules) {
      final reg = RegExp(rule.$1, caseSensitive: false, unicode: true);
      if (reg.hasMatch(lower)) {
        detectedKeywords.add(rule.$2);
        alerts.add(rule.$3);
        primaryAlert ??= rule.$3;
      }
    }

    // Baseline calculation: each matched threat pattern adds severity
    double score = 0.0;
    String? scamAlertType;
    String? scamAlertMessage;
    bool scamAlertActive = false;

    if (detectedKeywords.contains('otp_threat') || detectedKeywords.contains('pin_threat')) {
      scamAlertType = 'otp_asked';
      scamAlertMessage = 'Caller is aggressively asking for your OTP or PIN. NEVER enter or disclose your security code!';
      scamAlertActive = true;
      score = 0.90 + (detectedKeywords.length * 0.03);
    } else if (detectedKeywords.contains('digital_arrest')) {
      scamAlertType = 'digital_arrest';
      scamAlertMessage = 'CRITICAL: Digital Arrest extortion scam detected. Law enforcement agencies never arrest people via video/voice calls!';
      scamAlertActive = true;
      score = 0.95;
    } else if (detectedKeywords.contains('transfer_request')) {
      scamAlertType = 'money_asked';
      scamAlertMessage = 'Urgent money transfer demand detected. Verify recipient authenticity before sending funds!';
      scamAlertActive = true;
      score = 0.85 + (detectedKeywords.length * 0.03);
    } else if (detectedKeywords.contains('kyc_urgency')) {
      scamAlertType = 'kyc_scam';
      scamAlertMessage = 'Fake KYC verification threat detected. Official bank accounts are not blocked over unsolicited calls!';
      scamAlertActive = true;
      score = 0.80 + (detectedKeywords.length * 0.03);
    } else if (detectedKeywords.contains('bank_details') || detectedKeywords.contains('card_details')) {
      scamAlertType = 'bank_details_asked';
      scamAlertMessage = 'Caller is soliciting sensitive banking credentials or CVV numbers. Hang up immediately!';
      scamAlertActive = true;
      score = 0.78 + (detectedKeywords.length * 0.03);
    } else if (detectedKeywords.isNotEmpty) {
      score = 0.40 + (detectedKeywords.length * 0.15);
    }

    return ThreatAlertResult(
      intentScore: score.clamp(0.0, 1.0),
      detectedKeywords: detectedKeywords,
      alerts: alerts,
      primaryAlert: primaryAlert,
      scamAlertType: scamAlertType,
      scamAlertMessage: scamAlertMessage,
      scamAlertActive: scamAlertActive,
    );
  }
}
