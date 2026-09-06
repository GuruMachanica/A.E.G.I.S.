import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/call_record.dart';

class BackendException implements Exception {
  final String message;
  const BackendException(this.message);

  @override
  String toString() => message;
}

class BackendService {
  BackendService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  int _activeBaseIndex = 0;

  List<String> _baseCandidates() {
    final urls = <String>[];
    final configured = backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      urls.add(configured);
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (!urls.contains('http://127.0.0.1:8000')) {
        urls.add('http://127.0.0.1:8000');
      }
      if (!urls.contains('http://10.0.2.2:8000')) {
        urls.add('http://10.0.2.2:8000');
      }
    }

    if (urls.isEmpty) {
      urls.add('http://127.0.0.1:8000');
    }
    return urls;
  }

  Uri _uri(String path, String baseUrl) => Uri.parse('$baseUrl$path');

  String _extractErrorMessage(Map<String, dynamic> payload, int statusCode) {
    final detail = payload['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map<String, dynamic>) {
        final msg = first['msg'];
        if (msg is String && msg.trim().isNotEmpty) {
          return msg;
        }
      }
    }
    final message = payload['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return 'Request failed ($statusCode).';
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final candidates = _baseCandidates();
    Object? lastNetworkError;
    http.Response? response;

    final ordered = <String>[
      candidates[_activeBaseIndex % candidates.length],
      ...candidates.where(
        (url) => url != candidates[_activeBaseIndex % candidates.length],
      ),
    ];

    for (final baseUrl in ordered) {
      final uri = _uri(path, baseUrl);
      try {
        if (method == 'GET') {
          response = await _client
              .get(uri, headers: headers)
              .timeout(networkTimeout);
        } else if (method == 'DELETE') {
          response = await _client
              .delete(uri, headers: headers)
              .timeout(networkTimeout);
        } else if (method == 'POST') {
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(networkTimeout);
        } else {
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(networkTimeout);
        }
        _activeBaseIndex = candidates.indexOf(baseUrl);
        break;
      } catch (e) {
        lastNetworkError = e;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    if (response == null) {
      throw BackendException('Network error: $lastNetworkError');
    }

    Map<String, dynamic> payload = {};
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const BackendException('Invalid server response.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(
        _extractErrorMessage(payload, response.statusCode),
      );
    }

    return payload;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) {
    return _request(
      method: 'POST',
      path: '/auth/register',
      body: {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) {
    return _request(
      method: 'POST',
      path: '/auth/login',
      body: {'phone': phone, 'password': password},
    );
  }

  Future<Map<String, dynamic>> googleLogin({
    required String email,
    required String fullName,
    required String googleId,
    String? idToken,
  }) {
    return _request(
      method: 'POST',
      path: '/auth/google-login',
      body: {
        'email': email,
        'full_name': fullName,
        'google_id': googleId,
        'id_token': idToken ?? '',
      },
    );
  }

  Future<Map<String, dynamic>> verifyLoginOtp({
    required String pendingToken,
    required String otp,
  }) {
    return _request(
      method: 'POST',
      path: '/auth/login/verify-otp',
      body: {'pending_token': pendingToken, 'otp': otp},
    );
  }

  Future<Map<String, dynamic>> refreshSession({required String refreshToken}) {
    return _request(
      method: 'POST',
      path: '/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
  }

  Future<void> logoutAllDevices({required String token}) async {
    await _request(
      method: 'POST',
      path: '/auth/logout-all',
      token: token,
      body: const {},
    );
  }

  Future<void> requestPasswordReset({required String phone}) async {
    await _request(
      method: 'POST',
      path: '/auth/password/reset-request',
      body: {'phone': phone},
    );
  }

  Future<void> updatePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _request(
      method: 'PUT',
      path: '/auth/password',
      token: token,
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<void> setPassword({
    required String token,
    required String phone,
    required String newPassword,
  }) async {
    await _request(
      method: 'POST',
      path: '/auth/set-password',
      token: token,
      body: {'phone': phone, 'new_password': newPassword},
    );
  }

  Future<Map<String, dynamic>> start2FA({
    required String token,
    required String channel,
    required String destination,
  }) {
    return _request(
      method: 'POST',
      path: '/auth/2fa/start',
      token: token,
      body: {'channel': channel, 'destination': destination},
    );
  }

  Future<void> verify2FA({required String token, required String otp}) async {
    await _request(
      method: 'POST',
      path: '/auth/2fa/verify',
      token: token,
      body: {'otp': otp},
    );
  }

  Future<void> updateProfile({
    required String token,
    required String fullName,
    required String email,
    required bool autoDeleteLogs,
    required bool is2FAEnabled,
  }) async {
    await _request(
      method: 'PUT',
      path: '/profile',
      token: token,
      body: {
        'full_name': fullName,
        'email': email,
        'auto_delete_logs': autoDeleteLogs,
        'two_fa_enabled': is2FAEnabled,
      },
    );
  }

  Future<void> syncHistory({
    required String token,
    required List<CallRecord> records,
  }) async {
    await _request(
      method: 'POST',
      path: '/history/sync',
      token: token,
      body: {'records': records.map((r) => r.toJson()).toList()},
    );
  }

  Future<List<CallRecord>> fetchHistory({
    required String token,
    int limit = 200,
  }) async {
    final payload = await _request(
      method: 'GET',
      path: '/history?limit=$limit',
      token: token,
    );
    final recordsRaw = payload['records'];
    if (recordsRaw is! List) return const [];
    return recordsRaw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(CallRecord.fromJson)
        .toList();
  }

  Future<void> clearHistory({required String token}) async {
    await _request(method: 'DELETE', path: '/history', token: token);
  }

  Future<Map<String, dynamic>> fetchProfile({required String token}) {
    return _request(method: 'GET', path: '/profile', token: token);
  }

  Future<Map<String, dynamic>> fetchLatestAiAnalysis() {
    return _request(method: 'GET', path: '/assist/analysis/latest');
  }

  Uri latestAiReportPdfUrl() {
    final candidates = _baseCandidates();
    final active = candidates[_activeBaseIndex % candidates.length];
    return _uri('/assist/analysis/latest/pdf', active);
  }
}

final backendServiceProvider = Provider<BackendService>((ref) {
  return BackendService();
});
