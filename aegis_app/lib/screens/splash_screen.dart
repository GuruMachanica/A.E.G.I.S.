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
  late final AnimationController _loaderController;

  @override
  void initState() {
    super.initState();
    _loaderController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/welcome');
    });
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentTeal.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AegisLogo(size: 170),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 900.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 900.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 36),
              Text(
                'A.E.G.I.S.',
                style: GoogleFonts.rajdhani(
                  color: textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ).animate(delay: 250.ms).fadeIn(duration: 500.ms),
              const SizedBox(height: 10),
              SizedBox(
                width: 34,
                height: 34,
                child: AnimatedBuilder(
                  animation: _loaderController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _loaderController.value * 6.283,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accentTeal,
                            width: 2,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: accentTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Securing your communication...',
                style: GoogleFonts.rajdhani(
                  color: textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
