import 'package:flutter/material.dart';
import '../core/colors.dart';

/// Renders the redesigned high-tech A.E.G.I.S cyber shield logo with neon glow.
class AegisLogo extends StatelessWidget {
  final double size;
  final String? assetPath;
  final bool showGlow;

  const AegisLogo({
    super.key,
    this.size = 160,
    this.assetPath,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final img = assetPath ?? 'assets/images/aegis_logo.png';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showGlow)
            Container(
              width: size * 1.15,
              height: size * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentCyan.withValues(alpha: 0.28),
                    accentEmerald.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          Image.asset(
            img,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => CustomPaint(
              size: Size(size, size),
              painter: _ShieldPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [accentCyan.withValues(alpha: 0.35), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.6));
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.55, glowPaint);

    final shieldPath = _buildShieldPath(w, h);

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF0F1E2E), const Color(0xFF070B14)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentCyan, accentEmerald, accentCyan],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(shieldPath, fillPaint);
    canvas.drawPath(shieldPath, borderPaint);

    // Modern cyber "A" emblem
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'A',
        style: TextStyle(
          fontSize: w * 0.45,
          fontWeight: FontWeight.w900,
          fontFamily: 'Rajdhani',
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, accentCyan],
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
