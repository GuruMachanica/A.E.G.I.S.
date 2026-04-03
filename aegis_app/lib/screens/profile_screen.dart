import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/aegis_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  bool _editingName = false;
  bool _editingEmail = false;
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider);
    _nameCtrl = TextEditingController(text: p.fullName);
    _emailCtrl = TextEditingController(text: p.email);
    _phoneCtrl.text = p.phoneNumber;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    if (profile.fullName.isEmpty && auth.fullName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(profileProvider.notifier)
            .setIdentity(
              name: auth.fullName,
              email: auth.email,
              phone: auth.phoneNumber,
            );
      });
    }
    if (_nameCtrl.text != profile.fullName) _nameCtrl.text = profile.fullName;
    if (_emailCtrl.text != profile.email) _emailCtrl.text = profile.email;
    if (_phoneCtrl.text != profile.phoneNumber) {
      _phoneCtrl.text = profile.phoneNumber;
    }

    return Container(
      decoration: const BoxDecoration(gradient: bgGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              if (profile.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: riskYellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: riskYellow.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    profile.errorMessage!,
                    style: GoogleFonts.rajdhani(
                      color: riskYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              // ── PART 1: Profile Header ──────────────────────────────────────
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Avatar circle
                    Container(
                      key: const ValueKey('profile-avatar-circle'),
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentTealDark,
                        border: Border.all(color: accentTealDim, width: 2),
                      ),
                      child: profile.avatarPath.isNotEmpty
                          ? ClipOval(
                              child: Image.file(
                                File(profile.avatarPath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.person_rounded,
                                      color: accentTeal,
                                      size: 48,
                                    ),
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: accentTeal,
                              size: 48,
                            ),
                    ),
                    // Update button
                    Positioned(
                      key: const ValueKey('profile-avatar-update-button'),
                      bottom: -4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentTeal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Update',
                              style: GoogleFonts.rajdhani(
                                color: bgPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Shield badge
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AegisLogo(size: 30),
                    const SizedBox(width: 8),
                    Text(
                      'A.E.G.I.S. User',
                      style: GoogleFonts.rajdhani(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  profile.fullName.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Center(
                child: Text(
                  profile.email,
                  style: GoogleFonts.rajdhani(
                    color: textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── PART 1 cont: Manage Account Details ────────────────────────
              _SectionCard(
                title: 'Manage Account Details',
                children: [
                  // Full Name
                  _EditableField(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    editing: _editingName,
                    controller: _nameCtrl,
                    locked: false,
                    onToggleEdit: () {
                      if (_editingName) {
                        ref
                            .read(profileProvider.notifier)
                            .updateFullName(_nameCtrl.text.trim());
                      }
                      setState(() => _editingName = !_editingName);
                    },
                  ),
                  _Divider(),
                  // Email
                  _EditableField(
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    editing: _editingEmail,
                    controller: _emailCtrl,
                    locked: false,
                    onToggleEdit: () {
                      if (_editingEmail) {
                        ref
                            .read(profileProvider.notifier)
                            .updateEmail(_emailCtrl.text.trim());
                      }
                      setState(() => _editingEmail = !_editingEmail);
                    },
                  ),
                  _Divider(),
                  // Phone (locked)
                  _EditableField(
                    icon: Icons.lock_outline,
                    label: 'Phone Number',
                    editing: false,
                    controller: _phoneCtrl,
                    locked: true,
                    onToggleEdit: () {},
                  ),
                  _Divider(),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(profileProvider.notifier)
                            .saveProfileDetails(
                              name: _nameCtrl.text.trim(),
                              email: _emailCtrl.text.trim(),
                            );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: bgSurface,
                            content: Text(
                              'Profile updated successfully.',
                              style: GoogleFonts.rajdhani(color: accentTeal),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentTealDark,
                        side: const BorderSide(color: accentTealDim),
                      ),
                      child: Text(
                        'Upload Profile',
                        style: GoogleFonts.rajdhani(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _Divider(),
                  // Auto Delete toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto Delete Logs (older than 7 days)',
                                style: GoogleFonts.rajdhani(
                                  color: textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Auto Delete Logs for sharing than 7 days where your privacy is maintained.',
                                style: GoogleFonts.rajdhani(
                                  color: textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: profile.autoDeleteLogs,
                          onChanged: (_) {
                            ref
                                .read(profileProvider.notifier)
                                .toggleAutoDeleteLogs();
                          },
                          activeThumbColor: accentTeal,
                          inactiveThumbColor: textMuted,
                          inactiveTrackColor: inputBorder,
                        ),
                      ],
                    ),
                  ),
                ],
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── PART 2: Security Settings ──────────────────────────────────
              _SectionCard(
                title: 'Security Settings',
                children: [
                  _SettingsTile(
                    icon: Icons.lock_reset_outlined,
                    iconColor: accentTeal,
                    label: 'Update Password',
                    onTap: () => _showUpdatePasswordSheet(context),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.security_outlined,
                    iconColor: accentTeal,
                    label: 'Two-Factor Authentication (2FA)',
                    trailing: GestureDetector(
                      onTap: () => _handle2FA(context, ref),
                      child: Text(
                        profile.is2FAEnabled ? 'Enabled' : 'Setup',
                        style: GoogleFonts.rajdhani(
                          color: accentTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () => _handle2FA(context, ref),
                  ),
                ],
              ).animate(delay: 150.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── PART 2: Call Logs & Privacy ────────────────────────────────
              _SectionCard(
                title: 'Call Logs & Privacy',
                children: [
                  _SettingsTile(
                    icon: Icons.phone_missed_outlined,
                    iconColor: riskRed,
                    label: 'Clear All Call Logs',
                    onTap: () => _confirmClearLogs(context, ref),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _confirmClearLogs(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: riskRed.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Clear All Call Logs',
                        style: GoogleFonts.rajdhani(
                          color: riskRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 16),

              // ── PART 2: About ──────────────────────────────────────────────
              _SectionCard(
                title: 'About A.E.G.I.S.',
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'v1.3.11',
                        style: GoogleFonts.rajdhani(
                          color: textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _openExternalLink(
                              context,
                              termsOfServiceUrl,
                              label: 'Terms of Service',
                            ),
                            child: Text(
                              'Terms',
                              style: GoogleFonts.rajdhani(
                                color: accentTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _openExternalLink(
                              context,
                              privacyPolicyUrl,
                              label: 'Privacy Policy',
                            ),
                            child: Text(
                              'Privacy',
                              style: GoogleFonts.rajdhani(
                                color: accentTeal,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => _confirmLogoutAllDevices(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: textSecondary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Log Out All Devices',
                        style: GoogleFonts.rajdhani(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: () => _confirmLogout(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: textSecondary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Log Out',
                        style: GoogleFonts.rajdhani(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => _confirmDeleteAccount(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: riskRed.withValues(alpha: 0.15),
                        side: BorderSide(
                          color: riskRed.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Delete Account',
                        style: GoogleFonts.rajdhani(
                          color: riskRed,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _confirmClearLogs(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AegisDialog(
        title: 'Clear All Logs?',
        message: 'This will permanently delete all call records.',
        confirmLabel: 'Clear',
        confirmColor: riskRed,
        onConfirm: () {
          ref.read(historyProvider.notifier).clearAll();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AegisDialog(
        title: 'Log Out?',
        message: 'You will be returned to the welcome screen.',
        confirmLabel: 'Log Out',
        confirmColor: textSecondary,
        onConfirm: () async {
          await ref.read(authProvider.notifier).logout();
          if (!context.mounted) return;
          Navigator.pop(context);
          context.go('/welcome');
        },
      ),
    );
  }

  void _confirmLogoutAllDevices(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AegisDialog(
        title: 'Log Out All Devices?',
        message: 'This will terminate all active sessions for your account.',
        confirmLabel: 'Log Out All',
        confirmColor: textSecondary,
        onConfirm: () async {
          final ok = await ref.read(authProvider.notifier).logoutAllDevices();
          if (!context.mounted) return;
          Navigator.pop(context);
          if (ok) {
            context.go('/welcome');
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: bgSurface,
              content: Text(
                ref.read(authProvider).errorMessage ??
                    'Unable to log out all devices.',
                style: GoogleFonts.rajdhani(color: riskYellow),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AegisDialog(
        title: 'Delete Account?',
        message:
            'This action is irreversible. All data will be permanently erased.',
        confirmLabel: 'Delete',
        confirmColor: riskRed,
        onConfirm: () {
          Navigator.pop(context);
          context.go('/welcome');
        },
      ),
    );
  }

  void _showUpdatePasswordSheet(BuildContext context) {
    final parentContext = context;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Password',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: oldCtrl,
              obscureText: true,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(hintText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(hintText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'Confirm New Password',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final message = await ref
                      .read(profileProvider.notifier)
                      .updatePassword(
                        currentPassword: oldCtrl.text,
                        newPassword: newCtrl.text,
                        confirmPassword: confirmCtrl.text,
                      );
                  if (!parentContext.mounted) return;
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: bgSurface,
                      content: Text(
                        message ?? 'Password updated successfully.',
                        style: GoogleFonts.rajdhani(
                          color: message == null ? accentTeal : riskYellow,
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentTealDark,
                  side: const BorderSide(color: accentTealDim),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Update',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle2FA(BuildContext context, WidgetRef ref) async {
    final parentContext = context;
    final profile = ref.read(profileProvider);
    if (profile.is2FAEnabled) {
      ref.read(profileProvider.notifier).disable2FA();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: bgSurface,
          content: Text(
            '2FA disabled.',
            style: GoogleFonts.rajdhani(color: textPrimary),
          ),
        ),
      );
      return;
    }

    await ref.read(profileProvider.notifier).start2FASetup();
    if (!context.mounted) return;
    final otpCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up Two-Factor Authentication',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Verification code sent to your registered email ${profile.email}.',
              style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                await ref.read(profileProvider.notifier).start2FASetup();
                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    backgroundColor: bgSurface,
                    content: Text(
                      'A new OTP has been sent to ${profile.email}.',
                      style: GoogleFonts.rajdhani(color: accentTeal),
                    ),
                  ),
                );
              },
              child: Text(
                'Resend OTP',
                style: GoogleFonts.rajdhani(
                  color: accentTeal,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.rajdhani(color: textPrimary),
              decoration: const InputDecoration(
                hintText: 'Enter 6-digit code',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  final verified = await ref
                      .read(profileProvider.notifier)
                      .verify2FA(otpCtrl.text);
                  if (!parentContext.mounted) return;
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      backgroundColor: bgSurface,
                      content: Text(
                        verified
                            ? '2FA enabled successfully.'
                            : 'Invalid verification code.',
                        style: GoogleFonts.rajdhani(
                          color: verified ? accentTeal : riskYellow,
                        ),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentTealDark,
                  side: const BorderSide(color: accentTealDim),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Verify & Enable',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    await ref.read(profileProvider.notifier).updateAvatarPath(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgSurface,
        content: Text(
          'Profile photo updated.',
          style: GoogleFonts.rajdhani(color: accentTeal),
        ),
      ),
    );
  }

  Future<void> _openExternalLink(
    BuildContext context,
    String url, {
    required String label,
  }) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: bgSurface,
          content: Text(
            '$label URL is not configured.',
            style: GoogleFonts.rajdhani(color: riskYellow),
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: bgSurface,
          content: Text(
            'Unable to open $label.',
            style: GoogleFonts.rajdhani(color: riskYellow),
          ),
        ),
      );
    }
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool editing;
  final TextEditingController controller;
  final bool locked;
  final VoidCallback onToggleEdit;

  const _EditableField({
    required this.icon,
    required this.label,
    required this.editing,
    required this.controller,
    required this.locked,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: accentTealDim, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: editing
                ? TextField(
                    controller: controller,
                    autofocus: true,
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 4,
                      ),
                    ),
                  )
                : Text(
                    controller.text,
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontSize: 14,
                    ),
                  ),
          ),
          if (!locked)
            GestureDetector(
              onTap: onToggleEdit,
              child: Icon(
                editing ? Icons.check_rounded : Icons.edit_outlined,
                color: editing ? accentTeal : textSecondary,
                size: 18,
              ),
            )
          else
            const Icon(Icons.lock_outline, color: textMuted, size: 16),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 14),
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(color: inputBorder, height: 0, thickness: 0.5);
  }
}

class _AegisDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _AegisDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: inputBorder, width: 0.8),
      ),
      title: Text(
        title,
        style: GoogleFonts.rajdhani(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(
            confirmLabel,
            style: GoogleFonts.rajdhani(
              color: confirmColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
