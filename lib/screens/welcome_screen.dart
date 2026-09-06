import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/aegis_logo.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onEnterShield() async {
      await ref.read(authProvider.notifier).loginLocalGuest();
      await ref.read(profileProvider.notifier).setIdentity(
        name: 'Shield Commander',
        email: 'commander@aegis.local',
        phone: '+91 98000 00000',
      );
      if (!context.mounted) return;
      context.go('/home');
    }

    return Scaffold(
      backgroundColor: bgPrimary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF0F1E33), bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Floating Transparent Cyber Shield Logo
                const AegisLogo(size: 160, showGlow: true)
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 28),

                Text(
                  'A.E.G.I.S.',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 6),

                Text(
                  'AUTONOMOUS EDGE GUARDIAN & INTELLIGENCE SYSTEM',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: accentCyan,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ).animate(delay: 350.ms).fadeIn(duration: 500.ms),

                const SizedBox(height: 12),

                Text(
                  '100% On-Device Threat Interception • Zero Cloud Exposure',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate(delay: 450.ms).fadeIn(duration: 500.ms),

                const Spacer(flex: 2),

                // Primary Hero Button: Instant Enter
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onEnterShield,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      foregroundColor: bgPrimary,
                      elevation: 8,
                      shadowColor: accentCyan.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 24,
                          color: bgPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ENTER LOCAL SHIELD',
                          style: GoogleFonts.rajdhani(
                            color: bgPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: 550.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: 14),

                // Secondary Button: Console Settings
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: bgSurface.withValues(alpha: 0.6),
                      side: const BorderSide(color: inputBorder, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Operator Console Settings',
                      style: GoogleFonts.rajdhani(
                        color: textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ).animate(delay: 650.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
