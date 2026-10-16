import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService._();

  static const String _kOnboardingCompleted = 'fitcheck_onboarding_completed';

  @visibleForTesting
  static bool? mockOnboardingCompleted;

  static final Map<String, Object> _inMemoryTestStore = {};

  static bool get _isTestEnv =>
      !kIsWeb &&
      (Platform.environment.containsKey('FLUTTER_TEST') ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test'));

  /// Returns whether the user has completed or skipped the onboarding flow.
  static Future<bool> isOnboardingCompleted() async {
    if (mockOnboardingCompleted != null) {
      return mockOnboardingCompleted!;
    }
    if (_isTestEnv && !_inMemoryTestStore.containsKey('real_prefs')) {
      return (_inMemoryTestStore[_kOnboardingCompleted] as bool?) ?? false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kOnboardingCompleted) ?? false;
    } catch (e) {
      debugPrint('[PREFS] Error reading onboarding status: $e');
      return (_inMemoryTestStore[_kOnboardingCompleted] as bool?) ?? false;
    }
  }

  /// Sets the onboarding completion status.
  static Future<void> setOnboardingCompleted(bool completed) async {
    if (mockOnboardingCompleted != null) {
      mockOnboardingCompleted = completed;
      return;
    }
    _inMemoryTestStore[_kOnboardingCompleted] = completed;
    if (_isTestEnv && !_inMemoryTestStore.containsKey('real_prefs')) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingCompleted, completed);
    } catch (e) {
      debugPrint('[PREFS] Error writing onboarding status: $e');
    }
  }

  /// Resets preferences (useful for testing or debugging).
  static Future<void> resetAll() async {
    mockOnboardingCompleted = null;
    _inMemoryTestStore.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[PREFS] Error clearing preferences: $e');
    }
  }
}
