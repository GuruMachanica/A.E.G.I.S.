import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/aegis_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _operatorNameController = TextEditingController(text: 'Shield Operator');
  final _pinController = TextEditingController();
  bool _usePin = false;

  @override
  void dispose() {
    _operatorNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _enterLocalShield() async {
    final name = _operatorNameController.text.trim().isNotEmpty
        ? _operatorNameController.text.trim()
        : 'Shield Operator';

    await ref.read(authProvider.notifier).loginLocalGuest(
      name: name,
    );
    await ref.read(profileProvider.notifier).setIdentity(
      name: name,
      email: 'operator@aegis.local',
      phone: '+91 98000 00000',
    );

    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [Color(0xFF0D1B2D), bgPrimary],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 28),

                // Floating Transparent Cyber Shield Logo
                const AegisLogo(size: 130, showGlow: true)
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.85, 0.85)),

                const SizedBox(height: 20),

                Text(
                  'A.E.G.I.S.',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 4),

                Text(
                  'AUTONOMOUS EDGE GUARDIAN • LOCAL CONSOLE',
                  style: GoogleFonts.rajdhani(
                    color: accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // 100% Privacy Guarantee Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: accentEmerald.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentEmerald.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentEmerald.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: accentEmerald,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '100% ON-DEVICE ARCHITECTURE',
                              style: GoogleFonts.rajdhani(
                                color: accentEmerald,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Zero cloud servers. No accounts, emails, or phone tracking required. All speech analysis is local.',
                              style: GoogleFonts.rajdhani(
                                color: textSecondary,
                                fontSize: 11,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 28),

                // Operator Customization Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: bgSurface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentCyan.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            color: accentCyan,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'LOCAL OPERATOR IDENTITY',
                            style: GoogleFonts.rajdhani(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _operatorNameController,
                        style: GoogleFonts.rajdhani(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter Operator Name / Callsign',
                          hintStyle: GoogleFonts.rajdhani(color: textMuted),
                          filled: true,
                          fillColor: bgPrimary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: accentCyan),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Require Device PIN on Startup',
                            style: GoogleFonts.rajdhani(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Switch(
                            value: _usePin,
                            onChanged: (v) => setState(() => _usePin = v),
                            activeThumbColor: accentCyan,
                            inactiveThumbColor: textMuted,
                            inactiveTrackColor: inputBorder,
                          ),
                        ],
                      ),
                      if (_usePin) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          style: GoogleFonts.rajdhani(
                            color: textPrimary,
                            fontSize: 18,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••',
                            hintStyle: GoogleFonts.rajdhani(
                              color: textMuted,
                              letterSpacing: 8,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: bgPrimary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // Hero Primary CTA: ENTER LOCAL SHIELD
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _enterLocalShield,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      foregroundColor: bgPrimary,
                      elevation: 8,
                      shadowColor: accentCyan.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 22,
                          color: bgPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ENTER LOCAL SHIELD',
                          style: GoogleFonts.rajdhani(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: bgPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.95, 0.95),
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 18),

                // Direct Bypass shortcut
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Text(
                    'Direct Bypass → Continue to Dashboard',
                    style: GoogleFonts.rajdhani(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ).animate(delay: 450.ms).fadeIn(duration: 400.ms),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
