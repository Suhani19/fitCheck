import 'package:flutter/foundation.dart';

/// Centralized runtime application configuration.
///
/// Supports runtime overrides via `--dart-define`:
/// - `FITCHECK_BACKEND_URL`: Custom backend URL.
/// - `AGORA_APP_ID`: Optional client-side Agora App ID override.
class AppConfig {
  AppConfig._();

  static const String _fitcheckBackendUrl = String.fromEnvironment(
    'FITCHECK_BACKEND_URL',
  );

  static const String _envAgoraAppId = String.fromEnvironment(
    'AGORA_APP_ID',
  );

  /// Resolves the backend base URL dynamically based on environment and platform.
  static String get backendUrl {
    if (_fitcheckBackendUrl.isNotEmpty) {
      final trimmed = _fitcheckBackendUrl.trim();
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Default Android emulator loopback alias
      return 'http://10.0.2.2:8000';
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        // When running locally in browser dev mode, connect to local FastAPI on port 8000
        if (host == 'localhost' || host == '127.0.0.1') {
          final scheme = Uri.base.scheme.startsWith('https') ? 'https' : 'http';
          return '$scheme://$host:8000';
        }
        // When deployed to Firebase Hosting or a production domain, use same-origin
        // relative URLs ("") to leverage Firebase Hosting rewrites (/api/** -> Cloud Run)
        // without cross-origin CORS overhead.
        return '';
      }
      return '';
    }

    return 'http://localhost:8000';
  }

  /// Optional override for Agora App ID.
  /// When empty, the client relies on the `app_id` returned dynamically
  /// by the backend `/runtime/session` response.
  static String get agoraAppIdOverride => _envAgoraAppId;
}
