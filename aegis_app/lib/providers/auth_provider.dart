import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../services/backend_service.dart';
import '../services/local_database_service.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final String accessToken;
  final String userId;
  final String phoneNumber;
  final String fullName;
  final String email;
  final String refreshToken;
  final DateTime? sessionExpiresAt;
  final bool isOtpRequired;
  final String pendingOtp;
  final String pendingOtpToken;
  final String otpDeliveryTarget;
  final String otpDeliveryChannel;
  final int failedLoginAttempts;
  final DateTime? firstFailedLoginAt;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
    this.accessToken = '',
    this.userId = '',
    this.phoneNumber = '',
    this.fullName = '',
    this.email = '',
    this.refreshToken = '',
    this.sessionExpiresAt,
    this.isOtpRequired = false,
    this.pendingOtp = '',
    this.pendingOtpToken = '',
    this.otpDeliveryTarget = '',
    this.otpDeliveryChannel = '',
    this.failedLoginAttempts = 0,
    this.firstFailedLoginAt,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? accessToken,
    String? userId,
    String? phoneNumber,
    String? fullName,
    String? email,
    String? refreshToken,
    DateTime? sessionExpiresAt,
    bool? isOtpRequired,
    String? pendingOtp,
    String? pendingOtpToken,
    String? otpDeliveryTarget,
    String? otpDeliveryChannel,
    int? failedLoginAttempts,
    DateTime? firstFailedLoginAt,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      accessToken: accessToken ?? this.accessToken,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionExpiresAt: sessionExpiresAt ?? this.sessionExpiresAt,
      isOtpRequired: isOtpRequired ?? this.isOtpRequired,
      pendingOtp: pendingOtp ?? this.pendingOtp,
      pendingOtpToken: pendingOtpToken ?? this.pendingOtpToken,
      otpDeliveryTarget: otpDeliveryTarget ?? this.otpDeliveryTarget,
      otpDeliveryChannel: otpDeliveryChannel ?? this.otpDeliveryChannel,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      firstFailedLoginAt: firstFailedLoginAt ?? this.firstFailedLoginAt,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _authKey = 'aegis_auth_state';
  static bool _googleInitialized = false;

  @override
  AuthState build() {
    Future.microtask(_hydrate);
    return const AuthState();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authKey);
    if (raw == null || raw.isEmpty) return;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    state = state.copyWith(
      isAuthenticated: (json['token'] as String? ?? '').isNotEmpty,
      accessToken: json['token'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      phoneNumber: json['phone'] as String? ?? '',
      fullName: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      sessionExpiresAt: DateTime.tryParse(
        json['sessionExpiresAt'] as String? ?? '',
      ),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _authKey,
      jsonEncode({
        'token': state.accessToken,
        'userId': state.userId,
        'phone': state.phoneNumber,
        'name': state.fullName,
        'email': state.email,
        'refreshToken': state.refreshToken,
        'sessionExpiresAt': state.sessionExpiresAt?.toIso8601String() ?? '',
      }),
    );
  }

  Future<void> _completeAuth({
    required String phone,
    required String name,
    required String email,
    required String token,
    required String userId,
    String refreshToken = '',
    DateTime? sessionExpiresAt,
  }) async {
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      accessToken: token,
      userId: userId,
      phoneNumber: phone,
      fullName: name,
      email: email,
      refreshToken: refreshToken,
      sessionExpiresAt:
          sessionExpiresAt ?? DateTime.now().add(const Duration(hours: 1)),
      isOtpRequired: false,
      pendingOtp: '',
      pendingOtpToken: '',
      otpDeliveryTarget: '',
      otpDeliveryChannel: '',
      failedLoginAttempts: 0,
      firstFailedLoginAt: null,
      clearError: true,
    );
    await _persist();
    await ref
        .read(localDatabaseProvider)
        .logEvent('auth', 'User authenticated: ${state.email}');
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref
          .read(backendServiceProvider)
          .register(
            fullName: fullName,
            phone: phone,
            email: email,
            password: password,
          );
      await _completeAuth(
        phone: phone,
        name: fullName,
        email: email,
        token: result['token']?.toString() ?? '',
        userId: result['user_id']?.toString() ?? phone,
        refreshToken: result['refresh_token']?.toString() ?? '',
        sessionExpiresAt: DateTime.now().add(
          Duration(seconds: (result['expires_in'] as num?)?.toInt() ?? 3600),
        ),
      );
      if (state.accessToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Registration succeeded but token is missing.',
        );
        return false;
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String phone,
    String fullName = '',
    String email = '',
    required String password,
  }) async {
    final now = DateTime.now();
    final first = state.firstFailedLoginAt;
    if (state.failedLoginAttempts >= 5 &&
        first != null &&
        now.difference(first) < const Duration(minutes: 5)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Too many attempts. Try again in a few minutes.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref
          .read(backendServiceProvider)
          .login(phone: phone, password: password);
      final resolvedName =
          result['full_name']?.toString() ??
          (fullName.isNotEmpty ? fullName : state.fullName);
      final resolvedEmail =
          result['email']?.toString() ??
          (email.isNotEmpty ? email : state.email);
      final token = result['token']?.toString() ?? '';
      final backendRequiresOtp =
          result['requires_otp'] == true ||
          (result['pending_token']?.toString().isNotEmpty ?? false);
      final requiresOtp = backendRequiresOtp;
      if (requiresOtp) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          accessToken: token,
          userId: result['user_id']?.toString() ?? phone,
          phoneNumber: phone,
          fullName: resolvedName,
          email: resolvedEmail,
          isOtpRequired: true,
          pendingOtp: '',
          pendingOtpToken: result['pending_token']?.toString() ?? '',
          otpDeliveryTarget:
              result['otp_destination_masked']?.toString() ??
              (resolvedEmail.isNotEmpty ? resolvedEmail : 'registered email'),
          otpDeliveryChannel:
              result['otp_channel']?.toString().toUpperCase() ?? 'EMAIL',
          failedLoginAttempts: 0,
          firstFailedLoginAt: null,
        );
        await ref
            .read(localDatabaseProvider)
            .logEvent('otp', 'Login OTP requested for $resolvedEmail');
        return true;
      }

      await _completeAuth(
        phone: phone,
        name: resolvedName,
        email: resolvedEmail,
        token: token,
        userId: result['user_id']?.toString() ?? phone,
        refreshToken: result['refresh_token']?.toString() ?? '',
        sessionExpiresAt: DateTime.now().add(
          Duration(seconds: (result['expires_in'] as num?)?.toInt() ?? 3600),
        ),
      );
      if (state.accessToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Login succeeded but token is missing.',
        );
        return false;
      }
      return true;
    } catch (e) {
      final attempts = state.failedLoginAttempts + 1;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
        failedLoginAttempts: attempts,
        firstFailedLoginAt: state.firstFailedLoginAt ?? now,
      );
      return false;
    }
  }

  Future<bool> verifyLoginOtp(String otp) async {
    if (otp.trim().length != 6) {
      state = state.copyWith(errorMessage: 'Invalid OTP code.');
      return false;
    }

    if (state.pendingOtpToken.isNotEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final result = await ref
            .read(backendServiceProvider)
            .verifyLoginOtp(
              pendingToken: state.pendingOtpToken,
              otp: otp.trim(),
            );
        await _completeAuth(
          phone: result['phone']?.toString() ?? state.phoneNumber,
          name: result['full_name']?.toString() ?? state.fullName,
          email: result['email']?.toString() ?? state.email,
          token: result['token']?.toString() ?? '',
          userId: result['user_id']?.toString() ?? state.userId,
          refreshToken: result['refresh_token']?.toString() ?? '',
          sessionExpiresAt: DateTime.now().add(
            Duration(seconds: (result['expires_in'] as num?)?.toInt() ?? 3600),
          ),
        );
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
        return false;
      }
    }
    state = state.copyWith(errorMessage: 'OTP verification is unavailable.');
    return false;
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(
          clientId: googleClientId.isEmpty ? null : googleClientId,
          serverClientId: googleServerClientId.isEmpty
              ? null
              : googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      final backendResult = await ref
          .read(backendServiceProvider)
          .googleLogin(
            email: account.email,
            fullName: account.displayName ?? 'Google User',
            googleId: account.id,
            idToken: idToken,
          );
      await _completeAuth(
        phone: backendResult['phone']?.toString() ?? '',
        name:
            backendResult['full_name']?.toString() ??
            (account.displayName ?? 'Google User'),
        email: backendResult['email']?.toString() ?? account.email,
        token: backendResult['token']?.toString() ?? '',
        userId: backendResult['user_id']?.toString() ?? account.id,
        refreshToken: backendResult['refresh_token']?.toString() ?? '',
        sessionExpiresAt: DateTime.now().add(
          Duration(
            seconds: (backendResult['expires_in'] as num?)?.toInt() ?? 3600,
          ),
        ),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> requestPasswordReset(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(backendServiceProvider).requestPasswordReset(phone: phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    await ref.read(localDatabaseProvider).logEvent('auth', 'User logged out');
  }

  Future<void> updatePhoneNumber(String phone) async {
    state = state.copyWith(phoneNumber: phone.trim(), clearError: true);
    await _persist();
  }

  Future<bool> completeGoogleCredentials({
    required String phone,
    required String newPassword,
  }) async {
    if (state.accessToken.isEmpty) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref
          .read(backendServiceProvider)
          .setPassword(
            token: state.accessToken,
            phone: phone,
            newPassword: newPassword,
          );
      state = state.copyWith(
        isLoading: false,
        phoneNumber: phone,
        clearError: true,
      );
      await _persist();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> refreshSessionToken() async {
    if (state.refreshToken.isEmpty) return false;
    try {
      final result = await ref
          .read(backendServiceProvider)
          .refreshSession(refreshToken: state.refreshToken);
      state = state.copyWith(
        accessToken: result['token']?.toString() ?? state.accessToken,
        refreshToken: result['refresh_token']?.toString() ?? state.refreshToken,
        sessionExpiresAt: DateTime.now().add(
          Duration(seconds: (result['expires_in'] as num?)?.toInt() ?? 3600),
        ),
        clearError: true,
      );
      await _persist();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureSessionValid() async {
    final expiry = state.sessionExpiresAt;
    if (expiry == null) return state.isAuthenticated;
    final remaining = expiry.difference(DateTime.now());
    if (remaining > const Duration(minutes: 2)) return true;
    return refreshSessionToken();
  }

  Future<bool> logoutAllDevices() async {
    if (state.accessToken.isEmpty) {
      await logout();
      return true;
    }
    try {
      await ref
          .read(backendServiceProvider)
          .logoutAllDevices(token: state.accessToken);
      await logout();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
