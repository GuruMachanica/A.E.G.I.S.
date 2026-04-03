import 'package:flutter/material.dart';
import '../core/colors.dart';

/// Draws the A.E.G.I.S shield logo.
/// Tries to load [assetPath] first; falls back to a custom-painted shield.
class AegisLogo extends StatelessWidget {
  final double size;
  final String? assetPath;

  const AegisLogo({super.key, this.size = 160, this.assetPath});

  @override
  Widget build(BuildContext context) {
    final img = assetPath ?? 'assets/images/aegis_app_logo.png';
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        img,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          size: Size(size, size),
          painter: _ShieldPainter(),
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Glow behind shield ────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [accentTeal.withValues(alpha: 0.25), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.6));
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.55, glowPaint);

    // ── Shield body ───────────────────────────────────────────────────────────
    final shieldPath = _buildShieldPath(w, h);

    // Outer border gradient
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accentTeal.withValues(alpha: 0.9),
          accentTealDim.withValues(alpha: 0.4),
          accentTeal.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    // Fill
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0D2E2E), const Color(0xFF061414)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(shieldPath, fillPaint);
    canvas.drawPath(shieldPath, borderPaint);

    // ── Inner shield outline ──────────────────────────────────────────────────
    final innerPath = _buildShieldPath(w * 0.78, h * 0.78)
      ..shift(Offset(w * 0.11, h * 0.08));
    final innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015
      ..color = accentTealDim.withValues(alpha: 0.5);
    canvas.drawPath(innerPath, innerBorder);

    // ── "A" letter ────────────────────────────────────────────────────────────
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          fontSize: w * 0.42,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                accentTeal.withValues(alpha: 0.8),
              ],
            ).createShader(Rect.fromLTWH(0, 0, w, h)),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(w / 2 - textPainter.width / 2, h * 0.28 - textPainter.height / 2),
    );
  }

  Path _buildShieldPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..lineTo(w * 0.95, h * 0.18)
      ..lineTo(w * 0.95, h * 0.52)
      ..quadraticBezierTo(w * 0.95, h * 0.82, w * 0.5, h * 0.98)
      ..quadraticBezierTo(w * 0.05, h * 0.82, w * 0.05, h * 0.52)
      ..lineTo(w * 0.05, h * 0.18)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
