import 'package:flutter/material.dart';
import '../core/colors.dart';

enum RiskLevel { safe, suspicious, danger }

extension RiskLevelX on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.safe:       return riskGreen;
      case RiskLevel.suspicious: return riskYellow;
      case RiskLevel.danger:     return riskRed;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.safe:       return 'SAFE';
      case RiskLevel.suspicious: return 'SUSPICIOUS';
      case RiskLevel.danger:     return 'SCAM';
    }
  }

  Color get bgColor {
    switch (this) {
      case RiskLevel.safe:       return const Color(0xFF0D2E1A);
      case RiskLevel.suspicious: return const Color(0xFF2E2100);
      case RiskLevel.danger:     return const Color(0xFF2E0D0D);
    }
  }
}
