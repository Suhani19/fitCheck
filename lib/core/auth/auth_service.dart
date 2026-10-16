import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// Exception thrown when authentication is missing, invalid, or expired.
class AuthException implements Exception {
  final String message;
  final int? statusCode;
  const AuthException(this.message, [this.statusCode]);

  @override
  String toString() => 'AuthException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Generic representation of an authenticated user in FitCheck.
class FitCheckUser {
  final String uid;
  final String? email;
  final String? displayName;

  const FitCheckUser({
    required this.uid,
    this.email,
    this.displayName,
  });
}

/// Abstract contract for authentication service.
/// Decouples UI and API clients from concrete Firebase implementations for clean testability.
abstract class AuthService {
  FitCheckUser? get currentUser;
  Stream<FitCheckUser?> get authStateChanges;
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<FitCheckUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<FitCheckUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signOut();
  bool get isConfigured;
}

/// Concrete Firebase Authentication service using `firebase_core` and `firebase_auth`.
class FirebaseAuthService implements AuthService {
  final fb_auth.FirebaseAuth? _customAuth;

  FirebaseAuthService({fb_auth.FirebaseAuth? auth}) : _customAuth = auth;

  fb_auth.FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    if (_isFirebaseReady) {
      try {
        return fb_auth.FirebaseAuth.instance;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool get _isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isConfigured => _auth != null;

  @override
  FitCheckUser? get currentUser {
    final u = _auth?.currentUser;
    if (u == null) return null;
    return FitCheckUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
    );
  }

  @override
  Stream<FitCheckUser?> get authStateChanges {
    final authInstance = _auth;
    if (authInstance == null) {
      return Stream.value(null);
    }
    return authInstance.authStateChanges().map((u) {
      if (u == null) return null;
      return FitCheckUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
      );
    });
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth?.currentUser;
    if (u == null) return null;
    return await u.getIdToken(forceRefresh);
  }

  @override
  Future<FitCheckUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final authInstance = _auth;
    if (authInstance == null) {
      throw const AuthException(
        'Firebase Authentication is not configured for web. '
        'Run "flutterfire configure" or supply credentials via --dart-define.',
      );
    }
    try {
      final cred = await authInstance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user!;
      return FitCheckUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_formatFirebaseAuthError(e));
    }
  }

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final authInstance = _auth;
    if (authInstance == null) {
      throw const AuthException(
        'Firebase Authentication is not configured for web. '
        'Run "flutterfire configure" or supply credentials via --dart-define.',
      );
    }
    try {
      final cred = await authInstance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user!;
      if (displayName != null && displayName.isNotEmpty) {
        await u.updateDisplayName(displayName);
      }
      return FitCheckUser(
        uid: u.uid,
        email: u.email,
        displayName: displayName ?? u.displayName,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthException(_formatFirebaseAuthError(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  static String _formatFirebaseAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in the Firebase Console.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? e.code;
    }
  }
}

