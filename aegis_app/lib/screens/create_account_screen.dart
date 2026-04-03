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

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  String _phoneNumber = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      _showSnack('Please agree to the Terms of Service.', isError: true);
      return;
    }
    if (_phoneNumber.trim().isEmpty) {
      _showSnack('Phone number is required.', isError: true);
      return;
    }

    final ok = await ref.read(authProvider.notifier).register(
          fullName: _nameController.text.trim(),
          phone: _phoneNumber.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (ok) {
      await ref.read(profileProvider.notifier).setIdentity(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneNumber.trim(),
          );
      if (!mounted) return;
      context.go('/home');
    } else {
      _showSnack(
        ref.read(authProvider).errorMessage ?? 'Account creation failed.',
        isError: true,
      );
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgSurface,
        content: Text(
          message,
          style: GoogleFonts.rajdhani(
            color: isError ? riskYellow : accentTeal,
          ),
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
                  const Center(child: AegisLogo(size: 80))
                      .animate()
                      .fadeIn(duration: 600.ms),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'CREATE YOUR ACCOUNT',
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.15),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Fill in your details to get started.',
                      style: GoogleFonts.rajdhani(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
                  const SizedBox(height: 28),
                  const FieldLabel('FULL NAME'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    decoration: _inputDecoration(hint: 'FULL NAME'),
                  ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 18),
                  const FieldLabel('EMAIL ADDRESS'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (value.isEmpty) return 'Email is required';
                      if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
                      return null;
                    },
                    decoration: _inputDecoration(hint: 'EMAIL ADDRESS'),
                  ).animate(delay: 230.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 18),
                  const FieldLabel('PHONE NUMBER'),
                  const SizedBox(height: 6),
                  PhoneField(
                    onChanged: (phone) => _phoneNumber = phone,
                  ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
                  const FieldHint('Used for secure 2FA'),
                  const SizedBox(height: 18),
                  const FieldLabel('PASSWORD'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                    decoration: _inputDecoration(hint: 'PASSWORD').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                  const FieldHint('Min. 8 characters'),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _agreedToTerms,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.rajdhani(
                                color: textSecondary, fontSize: 12),
                            children: [
                              const TextSpan(text: 'By continuing, I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: GoogleFonts.rajdhani(
                                    color: accentTeal, fontSize: 12),
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.rajdhani(
                                    color: accentTeal, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate(delay: 350.ms).fadeIn(duration: 400.ms),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      auth.errorMessage!,
                      style: GoogleFonts.rajdhani(color: riskYellow, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentTealDark,
                        side: const BorderSide(color: accentTealDim, width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
                              'CREATE YOUR ACCOUNT & VERIFY',
                              style: GoogleFonts.rajdhani(
                                color: textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: RichText(
                        text: TextSpan(
                          style:
                              GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
                          children: [
                            const TextSpan(text: 'Already have an account?  '),
                            TextSpan(
                              text: 'Log In',
                              style: GoogleFonts.rajdhani(
                                  color: accentTeal,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
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

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.rajdhani(color: textMuted, fontSize: 14),
    );
  }
}
