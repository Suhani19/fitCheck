// File generated / structured according to FlutterFire official specification.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Supports official FlutterFire configuration via `flutterfire configure`,
/// as well as zero-secret `--dart-define` parameters for web and CI:
///
/// - `FIREBASE_API_KEY`: Firebase Web API Key
/// - `FIREBASE_APP_ID`: Firebase Web App ID (e.g. 1:123456789:web:abcdef)
/// - `FIREBASE_PROJECT_ID`: Firebase Project ID (e.g. fitcheck-app)
/// - `FIREBASE_AUTH_DOMAIN`: Firebase Auth Domain (e.g. fitcheck-app.firebaseapp.com)
/// - `FIREBASE_MESSAGING_SENDER_ID`: Firebase Messaging Sender ID
/// - `FIREBASE_STORAGE_BUCKET`: Firebase Storage Bucket
/// - `FIREBASE_MEASUREMENT_ID`: Google Analytics Measurement ID (optional)
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// if (DefaultFirebaseOptions.isConfigured) {
///   await Firebase.initializeApp(
///     options: DefaultFirebaseOptions.currentPlatform,
///   );
/// }
/// ```
class DefaultFirebaseOptions {
  /// Indicates whether valid Firebase credentials have been configured.
  static bool get isConfigured {
    if (kIsWeb) {
      return web.apiKey.isNotEmpty &&
          web.appId.isNotEmpty &&
          web.projectId.isNotEmpty;
    }
    // For native Android/iOS, Firebase can also initialize via google-services.json
    // or GoogleService-Info.plist.
    return false;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB5NaxJDxnXTDxvxayIjZslpXLUWzhcnO8',
    appId: '1:543865704060:web:4c92420b79b7679f0bc3f9',
    messagingSenderId: '543865704060',
    projectId: 'fitcheck-by-overfit',
    authDomain: 'fitcheck-by-overfit.firebaseapp.com',
    storageBucket: 'fitcheck-by-overfit.firebasestorage.app',
    measurementId: 'G-L194C9GP8W',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.fitcheck.app'),
  );
}
