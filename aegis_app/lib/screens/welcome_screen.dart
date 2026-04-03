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
    final auth = ref.watch(authProvider);

    Future<void> onGoogleTap() async {
      final ok = await ref.read(authProvider.notifier).signInWithGoogle();
      if (!context.mounted) return;
      if (!ok) {
        final msg = ref.read(authProvider).errorMessage ?? 'Google sign-in failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: bgSurface,
            content: Text(msg, style: GoogleFonts.rajdhani(color: riskYellow)),
          ),
        );
        return;
      }
      final state = ref.read(authProvider);
      String phone = state.phoneNumber;
      if (phone.trim().isEmpty || phone.startsWith('google-')) {
        final credentials = await _askGoogleCredentials(context);
        if (!context.mounted) return;
        if (credentials == null) {
          await ref.read(authProvider.notifier).logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: bgSurface,
              content: Text(
                'Phone and password setup is required for Google login.',
                style: GoogleFonts.rajdhani(color: riskYellow),
              ),
            ),
          );
          return;
        }
        final phoneInput = credentials['phone'] ?? '';
        final passwordInput = credentials['password'] ?? '';
        final saved = await ref.read(authProvider.notifier).completeGoogleCredentials(
              phone: phoneInput,
              newPassword: passwordInput,
            );
        if (!context.mounted) return;
        if (!saved) {
          await ref.read(authProvider.notifier).logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: bgSurface,
              content: Text(
                ref.read(authProvider).errorMessage ?? 'Unable to save login credentials.',
                style: GoogleFonts.rajdhani(color: riskYellow),
              ),
            ),
          );
          return;
        }
        phone = phoneInput;
      }
      await ref.read(profileProvider.notifier).setIdentity(
            name: state.fullName,
            email: state.email,
            phone: phone,
          );
      if (!context.mounted) return;
      context.go('/home');
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accentTeal.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AegisLogo(size: 130),
                  ],
                ).animate().fadeIn(duration: 700.ms).scale(
                      begin: const Offset(0.85, 0.85),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 28),
                Text(
                  'A.E.G.I.S.',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideY(begin: 0.15),
                const SizedBox(height: 6),
                Text(
                  'Total Communication Security',
                  style: GoogleFonts.rajdhani(
                    color: textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ).animate(delay: 350.ms).fadeIn(duration: 500.ms),
                const Spacer(flex: 2),
                _GoogleButton(
                  loading: auth.isLoading,
                  onTap: onGoogleTap,
                ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3),
                const SizedBox(height: 16),
                _OutlinedActionButton(
                  label: 'Create Account',
                  onTap: () => context.go('/register'),
                ).animate(delay: 600.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    'Already have an account? Log In',
                    style: GoogleFonts.rajdhani(
                      color: accentTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 500.ms),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>?> _askGoogleCredentials(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete Account Setup',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set phone number and password for future phone login.',
              style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(hintText: 'Enter phone number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(hintText: 'Create password'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(hintText: 'Confirm password'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  final phone = phoneCtrl.text.trim();
                  final pass = passCtrl.text;
                  final confirm = confirmCtrl.text;
                  if (phone.isEmpty || pass.length < 8 || pass != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: bgSurface,
                        content: Text(
                          'Enter valid phone and matching 8+ char password.',
                          style: GoogleFonts.rajdhani(color: riskYellow),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {'phone': phone, 'password': pass});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentTealDark,
                  side: const BorderSide(color: accentTealDim),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final bool loading;
  const _GoogleButton({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: accentTealDark,
          side: const BorderSide(color: accentTealDim, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentTeal),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleIcon(),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.rajdhani(
                      color: textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends StatelessWidget {
  const _GoogleLogoPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GPainter());
  }
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final segments = [
      (0.0, 0.5, const Color(0xFF4285F4)),
      (0.5, 1.0, const Color(0xFF34A853)),
      (1.0, 1.5, const Color(0xFFFBBC05)),
      (1.5, 2.0, const Color(0xFFEA4335)),
    ];

    for (final (start, end, color) in segments) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.22
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.68),
        start * 3.14159,
        (end - start) * 3.14159,
        false,
        paint,
      );
    }

    final cutPaint = Paint()
      ..color = accentTealDark
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.13, r * 0.72, size.height * 0.26),
      cutPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: inputBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
