import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/services/preferences_service.dart';
import 'core/theme/fitcheck_theme.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FitCheckTheme.init();

  if (kIsWeb) {
    if (DefaultFirebaseOptions.isConfigured) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('[FIREBASE] Web initialized with DefaultFirebaseOptions.');
      } catch (e) {
        debugPrint('[FIREBASE] Web initialization error: $e');
      }
    } else {
      debugPrint(
        '[FIREBASE] Web credentials not configured. '
        'Provide via flutterfire configure or --dart-define.',
      );
    }
  } else {
    try {
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
      debugPrint('[FIREBASE] Native app initialized.');
    } catch (e) {
      debugPrint('[FIREBASE] Native initialization deferred/unavailable: $e');
    }
  }

  // Mark legacy onboarding as completed so any legacy preference check won't trap users
  await PreferencesService.setOnboardingCompleted(true);
  runApp(const FitCheckApp());
}