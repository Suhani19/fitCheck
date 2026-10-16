import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

class RuntimeSession {
  final String sessionId;
  final String agentId;
  final String interviewerId;
  final String interviewerName;
  final String channel;
  final int uid;
  final String rtcToken;
  final String appId;

  const RuntimeSession({
    required this.sessionId,
    required this.agentId,
    required this.interviewerId,
    this.interviewerName = '',
    required this.channel,
    required this.uid,
    required this.rtcToken,
    required this.appId,
  });

  factory RuntimeSession.fromJson(Map<String, dynamic> json) {
    final appIdFromBackend = json['app_id'] as String? ?? '';
    final resolvedAppId = appIdFromBackend.isNotEmpty
        ? appIdFromBackend
        : AppConfig.agoraAppIdOverride;

    final resolvedInterviewerId = json['interviewer_id'] as String? ?? json['character_id'] as String? ?? '';
    final resolvedInterviewerName = json['interviewer_name'] as String? ?? json['character_name'] as String? ?? '';

    return RuntimeSession(
      sessionId: json['session_id'] as String? ?? json['channel'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      interviewerId: resolvedInterviewerId,
      interviewerName: resolvedInterviewerName,
      channel: json['channel'] as String? ?? '',
      uid: json['uid'] as int? ?? 0,
      rtcToken: json['rtc_token'] as String? ?? '',
      appId: resolvedAppId,
    );
  }
}

class RuntimeApi {
  String get baseUrl => AppConfig.backendUrl;

  Future<RuntimeSession> createSession({
    required String interviewerId,
    String userId = 'default_user',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/runtime/session'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'interviewer_id': interviewerId,
        'character_id': interviewerId,
        'user_id': userId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Runtime session failed: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return RuntimeSession.fromJson(json);
  }

  Future<Map<String, dynamic>> endSession({
    required String sessionId,
    List<Map<String, String>> transcript = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/runtime/session/$sessionId/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transcript': transcript,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('End session failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

