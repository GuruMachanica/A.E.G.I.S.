import 'dart:async';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;
  int _telemetryStep = 0;
  Timer? _telemetryTimer;

  static const _bootSteps = [
    'INITIALIZING 100% ON-DEVICE ENGINE...',
    'CALIBRATING INT8 ACOUSTIC DSP...',
    'ARMING MULTILINGUAL THREAT REGEX...',
    'SYNAPSE ACTIVE • SHIELD ARMED',
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 550), (t) {
      if (!mounted) return;
      setState(() {
        if (_telemetryStep < _bootSteps.length - 1) {
          _telemetryStep++;
        }
      });
    });

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) context.go('/welcome');
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF0F1B30), bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating cyber ring
                    RotationTransition(
                      turns: _ringController,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentCyan.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: accentCyan,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentCyan,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Inner pulse glow
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentCyan.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AegisLogo(size: 175),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(
                    begin: const Offset(0.75, 0.75),
                    duration: 800.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 32),
              Text(
                'A.E.G.I.S.',
                style: GoogleFonts.rajdhani(
                  color: textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 5,
                ),
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 6),
              Text(
                'TOTAL COMMUNICATION SECURITY • EDGE DEFENSE',
                style: GoogleFonts.rajdhani(
                  color: accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
              const Spacer(flex: 2),
              // Boot telemetry readout
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bgSurface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: inputBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _bootSteps[_telemetryStep],
                      style: GoogleFonts.jetBrainsMono(
                        color: textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
