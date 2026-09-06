import 'dart:convert';
import '../models/call_record.dart';

class LocalReportService {
  /// Generates a comprehensive on-device forensic dossier for a call event.
  static String generateForensicReport({
    required CallRecord record,
    String transcript = '',
    List<String> detectedKeywords = const [],
    String? alertType,
    String? alertMessage,
  }) {
    final buffer = StringBuffer();
    final timeStr = record.callTime.toIso8601String();

    buffer.writeln('======================================================');
    buffer.writeln('       A.E.G.I.S. FORENSIC INCIDENT DOSSIER           ');
    buffer.writeln('       CONFIDENTIAL • PRIVACY DEFENSE RECORD          ');
    buffer.writeln('======================================================');
    buffer.writeln('REPORT ID:       AEGIS-INC-${record.id}');
    buffer.writeln('TIMESTAMP:       $timeStr');
    buffer.writeln('CALLER TARGET:   ${record.phoneNumber}');
    buffer.writeln('CALLER IDENTITY: ${record.callerName}');
    buffer.writeln('SECURITY STATUS: ${record.riskLevel.name.toUpperCase()}');
    buffer.writeln('------------------------------------------------------');
    buffer.writeln('                 RISK TELEMETRY                       ');
    buffer.writeln('------------------------------------------------------');
    buffer.writeln('OVERALL FRAUD SCORE:     ${record.riskScore}%');
    buffer.writeln('SYNTHETIC VOICE INDEX:   ${record.syntheticScore}%');
    buffer.writeln('SCAM INTENT INDEX:       ${record.intentScore}%');
    buffer.writeln('ACTIVE CALL QUARANTINED: ${record.isSuspended ? "YES" : "NO"}');
    if (alertType != null) {
      buffer.writeln('FLAGGED THREAT VECTOR:   $alertType');
    }
    if (alertMessage != null) {
      buffer.writeln('ALERT ADVISORY:          $alertMessage');
    }
    buffer.writeln('------------------------------------------------------');
    buffer.writeln('             DETECTED THREAT PATTERNS                 ');
    buffer.writeln('------------------------------------------------------');
    if (detectedKeywords.isEmpty) {
      buffer.writeln('No explicit extortion keywords detected.');
    } else {
      for (final kw in detectedKeywords) {
        buffer.writeln('  [!] MATCH: $kw');
      }
    }
    buffer.writeln('------------------------------------------------------');
    buffer.writeln('               RECORDED TRANSCRIPT                    ');
    buffer.writeln('------------------------------------------------------');
    if (transcript.trim().isEmpty) {
      buffer.writeln('(No transcript audio captured or silence recorded)');
    } else {
      buffer.writeln(transcript);
    }
    buffer.writeln('------------------------------------------------------');
    buffer.writeln('                RECOMMENDED ACTIONS                   ');
    buffer.writeln('------------------------------------------------------');
    if (record.riskScore >= 65) {
      buffer.writeln('1. BLOCK and QUARANTINE this phone number immediately.');
      buffer.writeln('2. DO NOT share OTP, UPI PIN, or bank credentials.');
      buffer.writeln('3. Report incident to National Cyber Crime Reporting');
      buffer.writeln('   Portal at https://cybercrime.gov.in or Call 1930.');
    } else {
      buffer.writeln('Routine call. No malicious activity confirmed.');
    }
    buffer.writeln('======================================================');
    buffer.writeln('Generated 100% on-device by A.E.G.I.S. Neural Shield');
    buffer.writeln('======================================================');

    return buffer.toString();
  }

  /// Exports forensic incident as structured JSON.
  static String generateForensicJson({
    required CallRecord record,
    String transcript = '',
    List<String> detectedKeywords = const [],
    String? alertType,
    String? alertMessage,
  }) {
    final payload = {
      'report_id': 'AEGIS-INC-${record.id}',
      'timestamp': record.callTime.toIso8601String(),
      'phone_number': record.phoneNumber,
      'caller_name': record.callerName,
      'risk_level': record.riskLevel.name,
      'scores': {
        'overall': record.riskScore,
        'synthetic_voice': record.syntheticScore,
        'scam_intent': record.intentScore,
      },
      'threat_details': {
        'alert_type': alertType,
        'alert_message': alertMessage,
        'keywords': detectedKeywords,
        'quarantined': record.isSuspended,
      },
      'transcript': transcript,
      'engine': '100% On-Device Neural Edge Shield',
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
