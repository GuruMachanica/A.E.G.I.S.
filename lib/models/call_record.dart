import 'risk_level.dart';

class CallRecord {
  final String id;
  final String callerName;
  final String phoneNumber;
  final DateTime callTime;
  final RiskLevel riskLevel;
  final int riskScore; // 0–100
  final int syntheticScore; // 0–100  (deepfake probability)
  final int intentScore; // 0–100  (scam intent)
  final bool isSuspended;
  final String? avatarAsset; // local asset path or null

  const CallRecord({
    required this.id,
    required this.callerName,
    required this.phoneNumber,
    required this.callTime,
    required this.riskLevel,
    required this.riskScore,
    this.syntheticScore = 0,
    this.intentScore = 0,
    this.isSuspended = false,
    this.avatarAsset,
  });

  static RiskLevel levelFromScore(int score) {
    if (score < 35) return RiskLevel.safe;
    if (score < 65) return RiskLevel.suspicious;
    return RiskLevel.danger;
  }

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    final riskScore = (json['riskScore'] as num?)?.toInt() ?? 0;
    final levelRaw = json['riskLevel']?.toString() ?? 'safe';
    final level = RiskLevel.values.firstWhere(
      (r) => r.name == levelRaw,
      orElse: () => levelFromScore(riskScore),
    );
    return CallRecord(
      id: json['id']?.toString() ?? '',
      callerName: json['callerName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      callTime:
          DateTime.tryParse(json['callTime']?.toString() ?? '') ??
          DateTime.now(),
      riskLevel: level,
      riskScore: riskScore,
      syntheticScore: (json['syntheticScore'] as num?)?.toInt() ?? 0,
      intentScore: (json['intentScore'] as num?)?.toInt() ?? 0,
      isSuspended: json['isSuspended'] == true,
      avatarAsset: json['avatarAsset']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerName': callerName,
      'phoneNumber': phoneNumber,
      'callTime': callTime.toIso8601String(),
      'riskLevel': riskLevel.name,
      'riskScore': riskScore,
      'syntheticScore': syntheticScore,
      'intentScore': intentScore,
      'isSuspended': isSuspended,
      'avatarAsset': avatarAsset,
    };
  }
}
