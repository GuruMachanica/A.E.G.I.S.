import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/aegis_logo.dart';
import '../widgets/form_helpers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _phoneNumber = '';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_phoneNumber.trim().isEmpty) {
      _showSnack('Please enter your phone number.', isError: true);
      return;
    }

    final ok = await ref
        .read(authProvider.notifier)
        .login(
          phone: _phoneNumber.trim(),
          email: ref.read(profileProvider).email,
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (ok && ref.read(authProvider).isOtpRequired) {
      _showOtpDialog();
      return;
    }

    if (ok) {
      final authState = ref.read(authProvider);
      final currentProfile = ref.read(profileProvider);
      await ref
          .read(profileProvider.notifier)
          .setIdentity(
            name: authState.fullName.isNotEmpty
                ? authState.fullName
                : currentProfile.fullName,
            email: authState.email.isNotEmpty
                ? authState.email
                : currentProfile.email,
            phone: _phoneNumber.trim(),
          );
      if (!mounted) return;
      context.go('/home');
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed.';
      _showSnack(err, isError: true);
    }
  }

  Future<void> _showOtpDialog() async {
    final otpCtrl = TextEditingController();
    final auth = ref.read(authProvider);
    showModalBottomSheet(
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
              'Email OTP Verification',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              auth.otpDeliveryTarget.isNotEmpty
                  ? 'OTP sent via ${auth.otpDeliveryChannel} to ${auth.otpDeliveryTarget}.'
                  : 'OTP sent to your registered account.',
              style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit OTP',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  final verified = await ref
                      .read(authProvider.notifier)
                      .verifyLoginOtp(otpCtrl.text);
                  if (!context.mounted) return;
                  if (!verified) {
                    _showSnack('Invalid OTP.', isError: true);
                    return;
                  }
                  await ref
                      .read(profileProvider.notifier)
                      .setIdentity(
                        name: auth.fullName.isNotEmpty
                            ? auth.fullName
                            : ref.read(profileProvider).fullName,
                        email: auth.email.isNotEmpty
                            ? auth.email
                            : ref.read(profileProvider).email,
                        phone: _phoneNumber.trim(),
                      );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentTealDark,
                  side: const BorderSide(color: accentTealDim),
                ),
                child: Text(
                  'Verify Login',
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

  Future<void> _forgotPassword() async {
    if (_phoneNumber.trim().isEmpty) {
      _showSnack('Enter your phone number first.', isError: true);
      return;
    }

    final ok = await ref
        .read(authProvider.notifier)
        .requestPasswordReset(_phoneNumber.trim());
    if (!mounted) return;

    _showSnack(
      ok
          ? 'Password reset OTP has been sent.'
          : (ref.read(authProvider).errorMessage ?? 'Password reset failed.'),
      isError: !ok,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgSurface,
        content: Text(
          message,
          style: GoogleFonts.rajdhani(color: isError ? riskYellow : accentTeal),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Center(
                    child: AegisLogo(size: 80),
                  ).animate().fadeIn(duration: 600.ms),
                  const SizedBox(height: 24),
                  Center(
                        child: Text(
                          'LOG IN TO YOUR ACCOUNT',
                          style: GoogleFonts.rajdhani(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      )
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.15),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Enter your phone number and password.',
                      style: GoogleFonts.rajdhani(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
                  const SizedBox(height: 24),
                  const FieldLabel('PHONE NUMBER'),
                  const SizedBox(height: 6),
                  PhoneField(
                    onChanged: (phone) => _phoneNumber = phone,
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                  const FieldHint('Enter your registered number.'),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FieldLabel('PASSWORD'),
                      GestureDetector(
                        onTap: _forgotPassword,
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.rajdhani(
                            color: accentTeal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontSize: 15,
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Minimum 8 characters'
                        : null,
                    decoration: InputDecoration(
                      hintText: 'PASSWORD',
                      hintStyle: GoogleFonts.rajdhani(
                        color: textMuted,
                        fontSize: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                  const FieldHint('Minimum 8 characters'),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Remember Me',
                        style: GoogleFonts.rajdhani(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      auth.errorMessage!,
                      style: GoogleFonts.rajdhani(
                        color: riskYellow,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A3A3A),
                        side: const BorderSide(color: inputBorder, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: accentTeal,
                              ),
                            )
                          : Text(
                              'LOG IN',
                              style: GoogleFonts.rajdhani(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/register'),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.rajdhani(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account?  "),
                            TextSpan(
                              text: 'Sign Up',
                              style: GoogleFonts.rajdhani(
                                color: accentTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: 450.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
