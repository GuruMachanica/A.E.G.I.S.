import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend_service.dart';
import '../services/local_database_service.dart';
import 'auth_provider.dart';

class ProfileState {
  final String fullName;
  final String email;
  final String phoneNumber;
  final String avatarPath;
  final bool autoDeleteLogs;
  final bool is2FAEnabled;
  final bool isLoading;
  final String pending2FACode;
  final String? errorMessage;

  const ProfileState({
    this.fullName = '',
    this.email = '',
    this.phoneNumber = '',
    this.avatarPath = '',
    this.autoDeleteLogs = false,
    this.is2FAEnabled = false,
    this.isLoading = false,
    this.pending2FACode = '',
    this.errorMessage,
  });

  ProfileState copyWith({
    String? fullName,
    String? email,
    String? phoneNumber,
    String? avatarPath,
    bool? autoDeleteLogs,
    bool? is2FAEnabled,
    bool? isLoading,
    String? pending2FACode,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarPath: avatarPath ?? this.avatarPath,
      autoDeleteLogs: autoDeleteLogs ?? this.autoDeleteLogs,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      isLoading: isLoading ?? this.isLoading,
      pending2FACode: pending2FACode ?? this.pending2FACode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'avatarPath': avatarPath,
      'autoDeleteLogs': autoDeleteLogs,
      'is2FAEnabled': is2FAEnabled,
      'pending2FACode': pending2FACode,
    };
  }

  factory ProfileState.fromJson(Map<String, dynamic> json) {
    return ProfileState(
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      avatarPath: json['avatarPath']?.toString() ?? '',
      autoDeleteLogs: json['autoDeleteLogs'] == true,
      is2FAEnabled: json['is2FAEnabled'] == true,
      pending2FACode: json['pending2FACode']?.toString() ?? '',
    );
  }
}

class ProfileNotifier extends Notifier<ProfileState> {
  static const _profileKey = 'aegis_profile_state';

  @override
  ProfileState build() {
    Future.microtask(_hydrate);
    return const ProfileState();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;

    final raw = prefs.getString(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      state = ProfileState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    final auth = ref.read(authProvider);
    if (auth.fullName.isNotEmpty || auth.email.isNotEmpty) {
      state = state.copyWith(
        fullName: auth.fullName.isNotEmpty ? auth.fullName : state.fullName,
        email: auth.email.isNotEmpty ? auth.email : state.email,
        phoneNumber: auth.phoneNumber.isNotEmpty
            ? auth.phoneNumber
            : state.phoneNumber,
      );
    }

    if (auth.accessToken.isNotEmpty) {
      try {
        final remote = await ref
            .read(backendServiceProvider)
            .fetchProfile(token: auth.accessToken);
        if (!ref.mounted) return;
        state = state.copyWith(
          fullName: remote['full_name']?.toString() ?? state.fullName,
          email: remote['email']?.toString() ?? state.email,
          phoneNumber: remote['phone']?.toString() ?? state.phoneNumber,
          autoDeleteLogs: remote['auto_delete_logs'] == true,
          is2FAEnabled: remote['two_fa_enabled'] == true,
          clearError: true,
        );
      } catch (e) {
        if (!ref.mounted) return;
        state = state.copyWith(errorMessage: e.toString());
      }
    }

    if (!ref.mounted) return;
    await _persist();
  }

  Future<void> _persist() async {
    final snapshot = state.toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(snapshot));
  }

  Future<void> _syncProfile() async {
    await ref.read(authProvider.notifier).ensureSessionValid();
    final token = ref.read(authProvider).accessToken;
    if (token.isEmpty) return;

    await ref
        .read(backendServiceProvider)
        .updateProfile(
          token: token,
          fullName: state.fullName,
          email: state.email,
          autoDeleteLogs: state.autoDeleteLogs,
          is2FAEnabled: state.is2FAEnabled,
        );
  }

  Future<void> setIdentity({
    required String name,
    required String email,
    required String phone,
  }) async {
    state = state.copyWith(
      fullName: name,
      email: email,
      phoneNumber: phone,
      clearError: true,
    );
    await _persist();
  }

  Future<void> updateAvatarPath(String path) async {
    state = state.copyWith(avatarPath: path, clearError: true);
    await _persist();
    await ref
        .read(localDatabaseProvider)
        .logEvent('profile', 'Profile picture updated');
  }

  Future<void> updateFullName(String name) async {
    state = state.copyWith(fullName: name, clearError: true);
    await _persist();
    try {
      await _syncProfile();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateEmail(String email) async {
    state = state.copyWith(email: email, clearError: true);
    await _persist();
    try {
      await _syncProfile();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> saveProfileDetails({
    required String name,
    required String email,
  }) async {
    state = state.copyWith(fullName: name, email: email, clearError: true);
    await _persist();
    try {
      await _syncProfile();
      await ref
          .read(localDatabaseProvider)
          .logEvent('profile', 'Profile updated');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleAutoDeleteLogs() async {
    state = state.copyWith(
      autoDeleteLogs: !state.autoDeleteLogs,
      clearError: true,
    );
    await _persist();
    try {
      await _syncProfile();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<String?> start2FASetup() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = ref.read(authProvider).accessToken;
    if (token.isEmpty) {
      state = state.copyWith(isLoading: false);
      return null;
    }

    try {
      await ref
          .read(backendServiceProvider)
          .start2FA(token: token, channel: 'email', destination: state.email);
      state = state.copyWith(
        isLoading: false,
        pending2FACode: '',
        clearError: true,
      );
      await _persist();
      await ref
          .read(localDatabaseProvider)
          .logEvent('otp', '2FA OTP sent to ${state.email}');
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> verify2FA(String code) async {
    final normalized = code.trim();
    if (normalized.length != 6) {
      state = state.copyWith(errorMessage: 'Invalid 2FA code.');
      return false;
    }

    final token = ref.read(authProvider).accessToken;
    if (token.isEmpty) {
      state = state.copyWith(errorMessage: 'Please login again to verify 2FA.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref
          .read(backendServiceProvider)
          .verify2FA(token: token, otp: normalized);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      is2FAEnabled: true,
      pending2FACode: '',
      clearError: true,
    );
    await _persist();
    return true;
  }

  Future<void> disable2FA() async {
    state = state.copyWith(
      is2FAEnabled: false,
      pending2FACode: '',
      clearError: true,
    );
    await _persist();
    try {
      await _syncProfile();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.trim().isEmpty ||
        newPassword.trim().isEmpty ||
        confirmPassword.trim().isEmpty) {
      return 'All fields are required.';
    }
    if (newPassword.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (newPassword != confirmPassword) {
      return 'Passwords do not match.';
    }
    if (newPassword == currentPassword) {
      return 'New password must be different.';
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final token = ref.read(authProvider).accessToken;
    if (token.isNotEmpty) {
      try {
        await ref
            .read(backendServiceProvider)
            .updatePassword(
              token: token,
              currentPassword: currentPassword,
              newPassword: newPassword,
            );
      } catch (e) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
        return e.toString();
      }
    }

    state = state.copyWith(isLoading: false, clearError: true);
    await _persist();
    return null;
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
