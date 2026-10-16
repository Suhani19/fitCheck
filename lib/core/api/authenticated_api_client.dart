import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../auth/auth_service.dart';

export '../auth/auth_service.dart' show AuthException;

/// Central authenticated HTTP API client for FitCheck.
/// Automatically acquires Firebase ID token, attaches `Authorization: Bearer <token>`,
/// detects 401 Unauthorized responses, triggers token refresh on expiry, and exposes auth states.
class AuthenticatedApiClient {
  final AuthService authService;
  final http.Client _httpClient;
  final String? _baseUrlOverride;

  AuthenticatedApiClient({
    required this.authService,
    http.Client? httpClient,
    String? baseUrlOverride,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrlOverride;

  String get baseUrl => _baseUrlOverride ?? AppConfig.backendUrl;

  /// Retrieves authorization headers with the current or refreshed ID token.
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool forceRefresh = false,
  }) async {
    final token = await authService.getIdToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw const AuthException('No authenticated user session found. Please sign in.', 401);
    }

    final headers = <String, String>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  /// Sends an authenticated GET request.
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return _sendWithRetry((tokenHeaders) => _httpClient.get(
          Uri.parse('$baseUrl$path'),
          headers: tokenHeaders,
        ), extraHeaders: headers);
  }

  /// Sends an authenticated POST request.
  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    String? rawBody,
    Map<String, String>? headers,
  }) async {
    final payload = rawBody ?? (body != null ? jsonEncode(body) : null);
    return _sendWithRetry((tokenHeaders) => _httpClient.post(
          Uri.parse('$baseUrl$path'),
          headers: tokenHeaders,
          body: payload,
        ), extraHeaders: headers);
  }

  /// Sends an authenticated PUT request.
  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _sendWithRetry((tokenHeaders) => _httpClient.put(
          Uri.parse('$baseUrl$path'),
          headers: tokenHeaders,
          body: body != null ? jsonEncode(body) : null,
        ), extraHeaders: headers);
  }

  /// Sends an authenticated DELETE request.
  Future<http.Response> delete(String path, {Map<String, String>? headers}) async {
    return _sendWithRetry((tokenHeaders) => _httpClient.delete(
          Uri.parse('$baseUrl$path'),
          headers: tokenHeaders,
        ), extraHeaders: headers);
  }

  /// Sends an authenticated multipart request (e.g. for resume file uploads).
  Future<http.Response> postMultipart(
    String path, {
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    return _sendWithRetry((tokenHeaders) async {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);
      final reqHeaders = Map<String, String>.from(tokenHeaders);
      reqHeaders.remove('Content-Type');
      if (headers != null) {
        reqHeaders.addAll(headers);
      }
      request.headers.addAll(reqHeaders);
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
      ));
      final streamedResponse = await _httpClient.send(request);
      return http.Response.fromStream(streamedResponse);
    }, extraHeaders: headers);
  }

  /// Handles automatic single retry upon 401 Unauthorized by forcing a token refresh.
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    Map<String, String>? extraHeaders,
  }) async {
    var headers = await _buildHeaders(extraHeaders: extraHeaders, forceRefresh: false);
    var response = await requestFn(headers);

    if (response.statusCode == 401) {
      // Attempt token refresh once
      headers = await _buildHeaders(extraHeaders: extraHeaders, forceRefresh: true);
      response = await requestFn(headers);
      if (response.statusCode == 401) {
        throw AuthException(
          'Session expired or unauthorized: ${response.body}',
          401,
        );
      }
    }

    return response;
  }
}
