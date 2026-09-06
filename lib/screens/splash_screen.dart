import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../widgets/aegis_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _pulseController;
  int _telemetryStep = 0;
  Timer? _telemetryTimer;

  static const _bootSteps = [
    'INITIALIZING 100% ON-DEVICE ENGINE...',
    'CALIBRATING INT8 ACOUSTIC DSP...',
    'ARMING MULTILINGUAL THREAT REGEX...',
    'ZERO CLOUD PRIVACY • SHIELD ARMED',
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) return;
      setState(() {
        if (_telemetryStep < _bootSteps.length - 1) {
          _telemetryStep++;
        }
      });
    });

    // Auto-enter home directly - 100% on-device, zero sign-in barrier
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: Stack(
        children: [
          // Cyberpunk Grid Background
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(),
            ),
          ),

          // Central Radial Ambient Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.15),
                  radius: 0.9,
                  colors: [
                    Color(0xFF0C192E),
                    Color(0x00070B14),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Centerpiece Holographic Logo & Telemetry Rings
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Counter-rotating outer tactical radar ring
                      RotationTransition(
                        turns: _ringController,
                        child: CustomPaint(
                          size: const Size(260, 260),
                          painter: _RadarRingPainter(accentColor: accentCyan),
                        ),
                      ),

                      // Reverse rotating inner emerald ring
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: -_ringController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(210, 210),
                              painter: _InnerRingPainter(accentColor: accentEmerald),
                            ),
                          );
                        },
                      ),

                      // Ambient Breathing Energy Aura
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + _pulseController.value * 0.12;
                          final opacity = 0.15 + _pulseController.value * 0.15;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    accentCyan.withValues(alpha: opacity),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Floating Transparent Shield Logo (No background box)
                      const AegisLogo(
                        size: 170,
                        showGlow: true,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 32),

                // Title & Holographic Tagline
                Text(
                  'A.E.G.I.S.',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(
                        color: accentCyan.withValues(alpha: 0.6),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentCyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: accentCyan.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'TOTAL COMMUNICATION SECURITY • 100% ON-DEVICE',
                    style: GoogleFonts.rajdhani(
                      color: accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                    ),
                  ),
                ).animate(delay: 350.ms).fadeIn(duration: 400.ms),

                const Spacer(flex: 2),

                // Real-Time Boot Diagnostics Console
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1322).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentCyan.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: accentEmerald,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentEmerald,
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _bootSteps[_telemetryStep],
                                style: GoogleFonts.jetBrainsMono(
                                  color: textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${((_telemetryStep + 1) / _bootSteps.length * 100).toInt()}%',
                            style: GoogleFonts.jetBrainsMono(
                              color: accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Glowing Progress Line
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (_telemetryStep + 1) / _bootSteps.length,
                          backgroundColor: const Color(0xFF142033),
                          valueColor: const AlwaysStoppedAnimation<Color>(accentCyan),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 16),

                // Privacy Commitment Guarantee
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: accentEmerald,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ZERO CALL DATA TRANSMITTED • 100% PRIVATE',
                      style: GoogleFonts.rajdhani(
                        color: textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarRingPainter extends CustomPainter {
  final Color accentColor;
  _RadarRingPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2 - 4;

    final ringPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    // Cardinal tick marks
    final tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final isMajor = i % 3 == 0;
      final len = isMajor ? 8.0 : 4.0;
      final p1 = Offset(
        center.dx + (radius - len) * math.cos(angle),
        center.dy + (radius - len) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Orbiting Glowing Node
    final nodePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx + radius * math.cos(0), center.dy + radius * math.sin(0)),
      4.5,
      nodePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnerRingPainter extends CustomPainter {
  final Color accentColor;
  _InnerRingPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2 - 4;

    final dashPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw dashed arcs
    for (int i = 0; i < 6; i++) {
      final start = (i * 60) * math.pi / 180;
      final sweep = 35 * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF0F1E33).withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    const spacing = 36.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
