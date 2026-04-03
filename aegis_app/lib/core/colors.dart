import 'package:flutter/material.dart';

// ─── Background ────────────────────────────────────────────────────────────────
const Color bgPrimary = Color(0xFF0A1022);
const Color bgSurface = Color(0xFF121A2E);
const Color bgInput = Color(0xFF111A2A);

// ─── Accent ────────────────────────────────────────────────────────────────────
const Color accentTeal = Color(0xFFFF4B2B);
const Color accentTealDim = Color(0xFF8A2E2B);
const Color accentTealDark = Color(0xFF2A2036);

// ─── Text ──────────────────────────────────────────────────────────────────────
const Color textPrimary = Color(0xFFF1F3FA);
const Color textSecondary = Color(0xFFB4BDD8);
const Color textMuted = Color(0xFF69708A);

// ─── Input / Border ────────────────────────────────────────────────────────────
const Color inputBorder = Color(0xFF253154);
const Color inputBorderFocus = Color(0xFFFF4B2B);

// ─── Risk ──────────────────────────────────────────────────────────────────────
const Color riskGreen  = Color(0xFF00E5A0);
const Color riskYellow = Color(0xFFFFC107);
const Color riskRed    = Color(0xFFFF3B3B);

// ─── Gradient helpers ──────────────────────────────────────────────────────────
const LinearGradient bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF12183A), Color(0xFF0A1022)],
);

const RadialGradient shieldGlowGradient = RadialGradient(
  center: Alignment.center,
  radius: 0.7,
  colors: [Color(0xFF2B1E3F), Color(0xFF0A1022)],
);
