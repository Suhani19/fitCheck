import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';

class MockTestAuthService implements AuthService {
  String? token = 'valid_test_token';
  int refreshCallCount = 0;
  FitCheckUser? _user = const FitCheckUser(uid: 'test-user-1', email: 'test@example.com');

  @override
  FitCheckUser? get currentUser => _user;

  @override
  Stream<FitCheckUser?> get authStateChanges => Stream.value(_user);

  @override
  bool get isConfigured => true;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshCallCount++;
      token = 'refreshed_test_token';
    }
    return token;
  }

  @override
  Future<FitCheckUser> signInWithEmailAndPassword({required String email, required String password}) async {
    _user = FitCheckUser(uid: 'test-user-1', email: email);
    token = 'signed_in_token';
    return _user!;
  }

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({required String email, required String password, String? displayName}) async {
    _user = FitCheckUser(uid: 'test-user-1', email: email, displayName: displayName);
    token = 'signed_up_token';
    return _user!;
  }

  @override
  Future<FitCheckUser> signInAsDemo() async {
    _user = const FitCheckUser(uid: 'demo-candidate-elena', email: 'elena.demo@fitcheck.io', displayName: 'Elena Rostova');
    token = 'demo_session_token';
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    token = null;
  }
}

void main() {
  group('AuthenticatedApiClient Tests', () {
    late MockTestAuthService authService;

    setUp(() {
      authService = MockTestAuthService();
    });

    test('Attaches Authorization Bearer token to requests', () async {
      String? observedAuthHeader;
      final mockHttp = MockClient((request) async {
        observedAuthHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final client = AuthenticatedApiClient(
        authService: authService,
        httpClient: mockHttp,
        baseUrlOverride: 'http://localhost:8000',
      );

      final resp = await client.get('/api/v1/candidates');
      expect(resp.statusCode, 200);
      expect(observedAuthHeader, 'Bearer valid_test_token');
    });

    test('Throws AuthException when user is signed out or has no token', () async {
      await authService.signOut();
      final mockHttp = MockClient((request) async => http.Response('ok', 200));

      final client = AuthenticatedApiClient(
        authService: authService,
        httpClient: mockHttp,
        baseUrlOverride: 'http://localhost:8000',
      );

      expect(
        () => client.get('/api/v1/candidates'),
        throwsA(isA<AuthException>()),
      );
    });

    test('Retries with refreshed token upon 401 Unauthorized', () async {
      int requestCount = 0;
      final capturedTokens = <String?>[];

      final mockHttp = MockClient((request) async {
        requestCount++;
        capturedTokens.add(request.headers['Authorization']);
        if (requestCount == 1) {
          // Simulate expired token returning 401
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'status': 'success after refresh'}), 200);
      });

      final client = AuthenticatedApiClient(
        authService: authService,
        httpClient: mockHttp,
        baseUrlOverride: 'http://localhost:8000',
      );

      final resp = await client.get('/api/v1/candidates');
      expect(resp.statusCode, 200);
      expect(requestCount, 2);
      expect(authService.refreshCallCount, 1);
      expect(capturedTokens[0], 'Bearer valid_test_token');
      expect(capturedTokens[1], 'Bearer refreshed_test_token');
    });

    test('Throws AuthException if retry after refresh still yields 401', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Still Unauthorized'}), 401);
      });

      final client = AuthenticatedApiClient(
        authService: authService,
        httpClient: mockHttp,
        baseUrlOverride: 'http://localhost:8000',
      );

      await expectLater(
        () => client.get('/api/v1/candidates'),
        throwsA(isA<AuthException>()),
      );
      expect(authService.refreshCallCount, 1);
    });
  });
}
