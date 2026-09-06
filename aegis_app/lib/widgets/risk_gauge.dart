import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

/// Holographic Dual-Ring / Speedometer Threat Gauge matching Stitch "Obsidian Aegis"
class RiskGauge extends StatefulWidget {
  final double score;
  final double? innerScore;
  final double size;
  final String? centerLabel;
  final String? subLabel;

  const RiskGauge({
    super.key,
    required this.score,
    this.innerScore,
    this.size = 180,
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
  late Animation<double> _innerAnim;
  double _prevScore = 0;
  double _prevInner = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _anim = Tween<double>(begin: 0, end: widget.score.clamp(0.0, 1.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _innerAnim = Tween<double>(
      begin: 0,
      end: (widget.innerScore ?? widget.score).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void didUpdateWidget(RiskGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score || old.innerScore != widget.innerScore) {
      _anim = Tween<double>(
        begin: _prevScore,
        end: widget.score.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _innerAnim = Tween<double>(
        begin: _prevInner,
        end: (widget.innerScore ?? widget.score).clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _prevScore = widget.score.clamp(0.0, 1.0);
      _prevInner = (widget.innerScore ?? widget.score).clamp(0.0, 1.0);
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
      animation: _controller,
      builder: (context, child) => _GaugeView(
        score: _anim.value,
        innerScore: _innerAnim.value,
        size: widget.size,
        centerLabel: widget.centerLabel,
        subLabel: widget.subLabel,
      ),
    );
  }
}

class _GaugeView extends StatelessWidget {
  final double score;
  final double innerScore;
  final double size;
  final String? centerLabel;
  final String? subLabel;

  const _GaugeView({
    required this.score,
    required this.innerScore,
    required this.size,
    this.centerLabel,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDanger = score >= 0.65;
    final isWarning = score >= 0.35 && score < 0.65;
    final primaryColor = isDanger
        ? riskRed
        : (isWarning ? riskYellow : accentCyan);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Holographic background glow
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha: isDanger ? 0.22 : 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _DualRingPainter(
              outerScore: score,
              innerScore: innerScore,
              primaryColor: primaryColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(score * 100).round()}%',
                style: GoogleFonts.rajdhani(
                  color: textPrimary,
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: primaryColor.withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              if (centerLabel != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.08),
                  child: Text(
                    centerLabel!,
                    style: GoogleFonts.rajdhani(
                      color: primaryColor,
                      fontSize: size * 0.075,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              if (subLabel != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: size * 0.06),
                  child: Text(
                    subLabel!,
                    style: GoogleFonts.rajdhani(
                      color: textSecondary,
                      fontSize: size * 0.065,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DualRingPainter extends CustomPainter {
  final double outerScore;
  final double innerScore;
  final Color primaryColor;

  const _DualRingPainter({
    required this.outerScore,
    required this.innerScore,
    required this.primaryColor,
  });

  static const double _start = -pi / 2; // Start from top
  static const double _sweep = 2 * pi;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerRadius = size.width * 0.44;
    final innerRadius = size.width * 0.36;

    // ── Outer Track ──────────────────────────────────────────────────────────
    final outerTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), outerRadius, outerTrackPaint);

    // ── Inner Track ──────────────────────────────────────────────────────────
    final innerTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), innerRadius, innerTrackPaint);

    // ── Outer Active Arc (Scam Intent / Overall Risk) ─────────────────────────
    if (outerScore > 0) {
      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * pi,
          colors: [
            accentCyan,
            outerScore >= 0.65 ? riskRed : (outerScore >= 0.35 ? riskYellow : accentEmerald),
          ],
          transform: const GradientRotation(-pi / 2),
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: outerRadius));

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: outerRadius),
        _start,
        _sweep * outerScore,
        false,
        outerPaint,
      );
    }

    // ── Inner Active Arc (Synthetic Voice Score) ─────────────────────────────
    if (innerScore > 0) {
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.028
        ..strokeCap = StrokeCap.round
        ..color = innerScore >= 0.65 ? riskRed : accentCyan;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: innerRadius),
        _start,
        _sweep * innerScore,
        false,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DualRingPainter old) =>
      old.outerScore != outerScore ||
      old.innerScore != innerScore ||
      old.primaryColor != primaryColor;
}
