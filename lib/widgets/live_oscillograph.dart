import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

class LiveOscillograph extends StatefulWidget {
  final double rms;
  final double db;
  final bool isSpeech;
  final bool isThreat;

  const LiveOscillograph({
    super.key,
    required this.rms,
    this.db = -60.0,
    this.isSpeech = false,
    this.isThreat = false,
  });

  @override
  State<LiveOscillograph> createState() => _LiveOscillographState();
}

class _LiveOscillographState extends State<LiveOscillograph>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isThreat
        ? riskRed
        : (widget.isSpeech ? accentCyan : textMuted);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isThreat
              ? riskRed.withValues(alpha: 0.5)
              : inputBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: activeColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE AUDIO SPECTRUM',
                style: GoogleFonts.rajdhani(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgPrimary,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: inputBorder),
                ),
                child: Text(
                  '${widget.db.toStringAsFixed(1)} dB',
                  style: GoogleFonts.jetBrainsMono(
                    color: activeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 48),
                  painter: _WaveformPainter(
                    rms: widget.rms,
                    phase: _anim.value,
                    color: activeColor,
                    isSpeech: widget.isSpeech,
                    random: _random,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double rms;
  final double phase;
  final Color color;
  final bool isSpeech;
  final math.Random random;

  _WaveformPainter({
    required this.rms,
    required this.phase,
    required this.color,
    required this.isSpeech,
    required this.random,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 36;
    final barWidth = (size.width - (barCount * 3)) / barCount;
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, barWidth);

    final midY = size.height / 2;
    final boost = (rms * 120).clamp(4.0, size.height * 0.95);

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + 3) + barWidth / 2;
      // Synthesize harmonic envelope modulated by live RMS
      final distFromCenter = (i - barCount / 2).abs() / (barCount / 2);
      final envelope = 1.0 - (distFromCenter * 0.65);
      final sineWave = math.sin((i / 5.0) + (phase * 2 * math.pi));
      final height = math.max(
        3.0,
        boost * envelope * (0.4 + (sineWave * 0.3).abs()),
      );

      final top = midY - (height / 2);
      final bottom = midY + (height / 2);

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        paint..color = color.withValues(alpha: 0.35 + (height / size.height) * 0.65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.rms != rms ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color;
  }
}
