import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

/// Animated semi-circular gauge (speedometer style) matching the A.E.G.I.S. design.
/// [score] is 0.0 – 1.0.
class RiskGauge extends StatefulWidget {
  final double score;
  final double size;
  final String? centerLabel;
  final String? subLabel;

  const RiskGauge({
    super.key,
    required this.score,
    this.size = 150,
    this.centerLabel,
    this.subLabel,
  });

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  double _prevScore = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: widget.score.clamp(0.0, 1.0))
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(RiskGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _anim = Tween<double>(
              begin: _prevScore, end: widget.score.clamp(0.0, 1.0))
          .animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _prevScore = widget.score.clamp(0.0, 1.0);
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => _GaugeView(
        score: _anim.value,
        size: widget.size,
        centerLabel: widget.centerLabel,
        subLabel: widget.subLabel,
      ),
    );
  }
}

class _GaugeView extends StatelessWidget {
  final double score;
  final double size;
  final String? centerLabel;
  final String? subLabel;

  const _GaugeView(
      {required this.score,
      required this.size,
      this.centerLabel,
      this.subLabel});

  @override
  Widget build(BuildContext context) {
    final gaugeH = size * 0.75;
    return SizedBox(
      width: size,
      height: gaugeH + (centerLabel != null ? size * 0.20 : 0),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(
            size: Size(size, gaugeH),
            painter: _GaugePainter(score: score),
          ),
          Positioned(
            top: gaugeH * 0.42,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(score * 100).round()}%',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: size * 0.20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (centerLabel != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: size * 0.06),
                    child: Text(
                      centerLabel!,
                      style: GoogleFonts.rajdhani(
                        color: textSecondary,
                        fontSize: size * 0.085,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                if (subLabel != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: size * 0.04),
                    child: Text(
                      subLabel!,
                      style: GoogleFonts.rajdhani(
                        color: textMuted,
                        fontSize: size * 0.07,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;

  const _GaugePainter({required this.score});

  // Arc starts at ~225° (7 o'clock) and sweeps 270°
  static const double _start = pi * 1.25;
  static const double _sweep = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final r = size.width * 0.41;
    final sw = size.width * 0.085;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Background track ────────────────────────────────────────────────────
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeCap = StrokeCap.round,
    );

    if (score <= 0) return;

    // ── Gradient-colored arc using small segments ────────────────────────────
    const int segs = 80;
    final segSweep = _sweep / segs;
    final filled = (score * segs).ceil();

    for (int i = 0; i < filled; i++) {
      final t = i / (segs - 1);
      canvas.drawArc(
        rect,
        _start + i * segSweep,
        segSweep * 1.05,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..color = _colorAt(t)
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── Needle dot at tip ────────────────────────────────────────────────────
    final tipAngle = _start + _sweep * score;
    canvas.drawCircle(
      Offset(cx + r * cos(tipAngle), cy + r * sin(tipAngle)),
      sw * 0.65,
      Paint()..color = Colors.white,
    );
  }

  Color _colorAt(double t) {
    if (t < 0.5) {
      return Color.lerp(
          const Color(0xFF00E5A0), const Color(0xFFFFC107), t * 2)!;
    }
    return Color.lerp(
        const Color(0xFFFFC107), const Color(0xFFFF3B3B), (t - 0.5) * 2)!;
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}
