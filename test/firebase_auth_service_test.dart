import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/firebase_options.dart';

void main() {
  group('FirebaseAuthService & DefaultFirebaseOptions Tests', () {
    test('DefaultFirebaseOptions.web has valid configured project credentials', () {
      expect(DefaultFirebaseOptions.web.apiKey, isNotEmpty);
      expect(DefaultFirebaseOptions.web.projectId, 'fitcheck-by-overfit');
      expect(DefaultFirebaseOptions.web.appId, '1:543865704060:web:4c92420b79b7679f0bc3f9');
      expect(DefaultFirebaseOptions.web.authDomain, 'fitcheck-by-overfit.firebaseapp.com');
    });

    test('FirebaseAuthService.isConfigured is false when uninitialized', () {
      final auth = FirebaseAuthService();
      expect(auth.isConfigured, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('FirebaseAuthService throws AuthException when signing in unconfigured', () async {
      final auth = FirebaseAuthService();
      expect(
        () => auth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Firebase Authentication is not configured for web'),
        )),
      );
    });

    test('FirebaseAuthService throws AuthException when signing up unconfigured', () async {
      final auth = FirebaseAuthService();
      expect(
        () => auth.signUpWithEmailAndPassword(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'Test Candidate',
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Firebase Authentication is not configured for web'),
        )),
      );
    });

    test('AuthException formats message correctly with and without statusCode', () {
      const errNoStatus = AuthException('Invalid email');
      expect(errNoStatus.toString(), 'AuthException: Invalid email');

      const errWithStatus = AuthException('Session expired', 401);
      expect(errWithStatus.toString(), 'AuthException: Session expired (status: 401)');
    });
  });
}

