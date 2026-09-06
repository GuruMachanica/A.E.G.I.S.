import 'package:flutter/foundation.dart';

String _defaultBackendBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8000',
    _ => 'http://127.0.0.1:8000',
  };
}

String _defaultBackendWsUrl() {
  if (kIsWeb) {
    return 'ws://127.0.0.1:8000/assist/live-audio';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ws://10.0.2.2:8000/assist/live-audio',
    _ => 'ws://127.0.0.1:8000/assist/live-audio',
  };
}

String _defaultSttWsUrl() {
  if (kIsWeb) {
    return 'ws://127.0.0.1:8002/asr';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ws://10.0.2.2:8002/asr',
    _ => 'ws://127.0.0.1:8002/asr',
  };
}

final String backendBaseUrl = (() {
  final configured = const String.fromEnvironment('AEGIS_API_BASE_URL').trim();
  return configured.isNotEmpty ? configured : _defaultBackendBaseUrl();
})();

final String backendWsUrl = (() {
  final configured = const String.fromEnvironment('AEGIS_WS_URL').trim();
  return configured.isNotEmpty ? configured : _defaultBackendWsUrl();
})();

final String sttWsUrl = (() {
  final configured = const String.fromEnvironment('AEGIS_STT_WS_URL').trim();
  return configured.isNotEmpty ? configured : _defaultSttWsUrl();
})();

const Duration networkTimeout = Duration(seconds: 12);

const String googleClientId = String.fromEnvironment(
  'AEGIS_GOOGLE_CLIENT_ID',
  defaultValue: '',
);

const String googleServerClientId = String.fromEnvironment(
  'AEGIS_GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

const String privacyPolicyUrl = String.fromEnvironment(
  'AEGIS_PRIVACY_URL',
  defaultValue: '',
);

const String termsOfServiceUrl = String.fromEnvironment(
  'AEGIS_TERMS_URL',
  defaultValue: '',
);
