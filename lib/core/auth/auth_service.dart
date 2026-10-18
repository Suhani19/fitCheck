import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

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
  Future<FitCheckUser> signInAsDemo();
  Future<void> signOut();
  bool get isConfigured;
}

/// Concrete Firebase Authentication service using `firebase_core` and `firebase_auth`.
class FirebaseAuthService implements AuthService {
  final fb_auth.FirebaseAuth? _customAuth;
  String? _demoToken;
  FitCheckUser? _demoUser;
  final StreamController<FitCheckUser?> _customAuthController = StreamController<FitCheckUser?>.broadcast();

  FirebaseAuthService({fb_auth.FirebaseAuth? auth}) : _customAuth = auth {
    _initAuthListener();
  }

  void _initAuthListener() {
    final authInstance = _auth;
    if (authInstance != null) {
      authInstance.authStateChanges().listen((u) {
        if (_demoUser != null) return;
        if (u == null) {
          _customAuthController.add(null);
        } else {
          _customAuthController.add(FitCheckUser(
            uid: u.uid,
            email: u.email,
            displayName: u.displayName,
          ));
        }
      });
    }
  }

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
    if (_demoUser != null) return _demoUser;
    final u = _auth?.currentUser;
    if (u == null) return null;
    return FitCheckUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
    );
  }

  @override
  Stream<FitCheckUser?> get authStateChanges => _customAuthController.stream;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_demoToken != null) return _demoToken;
    final u = _auth?.currentUser;
    if (u == null) return null;
    return await u.getIdToken(forceRefresh);
  }

  static const String _kDemoTokenKey = 'fitcheck_demo_token';
  static const String _kDemoUserKey = 'fitcheck_demo_user';

  @override
  Future<FitCheckUser> signInAsDemo() async {
    final base = AppConfig.backendUrl.trim();
    final url = base.isEmpty ? '/api/v1/auth/demo-session' : '$base/api/v1/auth/demo-session';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        throw AuthException('Failed to establish demo session: ${response.body}', response.statusCode);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final userData = data['user'] as Map<String, dynamic>;
      _demoToken = token;
      _demoUser = FitCheckUser(
        uid: userData['uid'] as String,
        email: userData['email'] as String?,
        displayName: userData['display_name'] as String?,
      );
    } catch (e) {
      debugPrint('[AuthService] signInAsDemo backend notice: $e');
      final uniqueDemoId = 'demo-cand-shinchan-${DateTime.now().millisecondsSinceEpoch}';
      _demoToken = uniqueDemoId;
      _demoUser = FitCheckUser(
        uid: uniqueDemoId,
        email: 'shinchan.demo@fitcheck.io',
        displayName: 'Shinchan Nohara',
      );
    }

    _customAuthController.add(_demoUser);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_demoToken != null) {
        await prefs.setString(_kDemoTokenKey, _demoToken!);
      }
      if (_demoUser != null) {
        await prefs.setString(
          _kDemoUserKey,
          jsonEncode({
            'uid': _demoUser!.uid,
            'email': _demoUser!.email,
            'displayName': _demoUser!.displayName,
          }),
        );
      }
    } catch (e) {
      debugPrint('[AuthService] Could not persist demo session: $e');
    }

    _customAuthController.add(_demoUser);
    return _demoUser!;
  }

  bool get isDemoUser => _demoUser != null;

  Future<FitCheckUser?> restoreDemoSession() async {
    if (_demoUser != null) return _demoUser;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_kDemoTokenKey);
      final savedUserJson = prefs.getString(_kDemoUserKey);
      if (savedToken == null || savedUserJson == null) return null;

      final userData = jsonDecode(savedUserJson) as Map<String, dynamic>;
      final user = FitCheckUser(
        uid: userData['uid'] as String,
        email: userData['email'] as String?,
        displayName: userData['displayName'] as String?,
      );

      _demoToken = savedToken;
      _demoUser = user;
      _customAuthController.add(_demoUser);
      return user;
    } catch (e) {
      debugPrint('[AuthService] Error restoring demo session: $e');
      return null;
    }
  }

  Future<void> clearDemoSession() async {
    _demoToken = null;
    _demoUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDemoTokenKey);
      await prefs.remove(_kDemoUserKey);
    } catch (_) {}
    _customAuthController.add(null);
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
    await clearDemoSession();
    await _auth?.signOut();
    _customAuthController.add(null);
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

extension DemoAuthExtension on AuthService {
  bool get isDemoUser {
    final s = this;
    if (s is FirebaseAuthService) return s.isDemoUser;
    final user = currentUser;
    if (user != null && (user.uid.startsWith('demo-') || user.email?.contains('demo') == true)) {
      return true;
    }
    return false;
  }

  Future<FitCheckUser?> restoreDemoSession() async {
    final s = this;
    if (s is FirebaseAuthService) return s.restoreDemoSession();
    return null;
  }

  Future<void> clearDemoSession() async {
    final s = this;
    if (s is FirebaseAuthService) await s.clearDemoSession();
  }
}

