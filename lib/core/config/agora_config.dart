import 'app_config.dart';

/// Deprecated: Agora App ID is dynamically provided by the backend runtime session
/// or configured via `--dart-define=AGORA_APP_ID=...`.
@Deprecated('Use AppConfig.agoraAppIdOverride or backend-provided app_id instead.')
String get agoraAppId => AppConfig.agoraAppIdOverride;