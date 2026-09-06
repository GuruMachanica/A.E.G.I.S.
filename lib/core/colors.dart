import 'package:flutter/material.dart';

// ─── Obsidian Cyber Palette (Stitch "Obsidian Aegis" Theme) ─────────────────────

// Backgrounds
const Color bgPrimary = Color(0xFF070B14);      // Deep Space Obsidian
const Color bgSurface = Color(0xFF0E1624);      // High-tech Glass Surface
const Color bgSurfaceLight = Color(0xFF162035); // Elevated Glass Surface
const Color bgInput = Color(0xFF0B1220);        // Input Terminal Background

// Accents
const Color accentCyan = Color(0xFF00F0FF);     // Glowing Neon Cyan
const Color accentTeal = Color(0xFF00F0FF);     // Primary Interactive Action
const Color accentTealDim = Color(0xFF007A82);  // Dim Neon Rim
const Color accentTealDark = Color(0xFF052A30); // Deep Cyan Hue
const Color accentEmerald = Color(0xFF00FF9D);  // Verified Clean / Safe Status

// Text
const Color textPrimary = Color(0xFFF1F5F9);    // Crisp Cyber White
const Color textSecondary = Color(0xFF94A3B8);  // Slate Gray Telemetry
const Color textMuted = Color(0xFF64748B);      // Subdued Terminal Text

// Borders & Rim Lighting
const Color inputBorder = Color(0xFF1E293B);    // 1px Glass Rim Light
const Color inputBorderFocus = Color(0xFF00F0FF);// Focused Cyan Bloom

// Threat & Risk Indicators
const Color riskGreen = Color(0xFF00FF9D);      // Safe (0% - 34%)
const Color riskYellow = Color(0xFFFFB800);     // Warning (35% - 64%)
const Color riskRed = Color(0xFFFF2A55);        // Danger / Critical Extortion (65%+)

// Gradients
const LinearGradient bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0A1120), Color(0xFF070B14)],
);

const RadialGradient shieldGlowGradient = RadialGradient(
  center: Alignment.center,
  radius: 0.75,
  colors: [Color(0xFF0B2538), Color(0xFF070B14)],
);

const LinearGradient cyanGlowGradient = LinearGradient(
  colors: [Color(0xFF00F0FF), Color(0xFF00A3FF)],
);

const LinearGradient threatGlowGradient = LinearGradient(
  colors: [Color(0xFFFF2A55), Color(0xFFFF6B00)],
);
