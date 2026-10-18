import 'package:flutter/foundation.dart';
import 'candidate_speech_recognition_stub.dart'
    if (dart.library.html) 'candidate_speech_recognition_web.dart';

/// Service interface for real-time speech-to-text recognition of candidate voice input.
/// Uses browser W3C Web Speech API on Web and safe stubs in non-web test environments.
abstract class CandidateSpeechRecognitionService {
  factory CandidateSpeechRecognitionService() => getCandidateSpeechRecognitionService();

  bool get isSupported;
  bool get isListening;
  ValueNotifier<bool> get isListeningNotifier;
  ValueNotifier<String> get interimTranscriptNotifier;
  ValueNotifier<String?> get errorNotifier;

  void startListening({
    required void Function(String interimText) onInterimResult,
    required void Function(String finalText) onFinalResult,
    void Function(String error)? onError,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  });

  void stopListening();
  void abort();
  void dispose();
}
