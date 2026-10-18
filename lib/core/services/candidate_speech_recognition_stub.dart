import 'package:flutter/foundation.dart';
import 'candidate_speech_recognition_service.dart';

CandidateSpeechRecognitionService getCandidateSpeechRecognitionService() {
  return StubCandidateSpeechRecognitionService();
}

class StubCandidateSpeechRecognitionService implements CandidateSpeechRecognitionService {
  final ValueNotifier<bool> _isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _interimTranscriptNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);

  @override
  bool get isSupported => false;

  @override
  bool get isListening => false;

  @override
  ValueNotifier<bool> get isListeningNotifier => _isListeningNotifier;

  @override
  ValueNotifier<String> get interimTranscriptNotifier => _interimTranscriptNotifier;

  @override
  ValueNotifier<String?> get errorNotifier => _errorNotifier;

  @override
  void startListening({
    required void Function(String interimText) onInterimResult,
    required void Function(String finalText) onFinalResult,
    void Function(String error)? onError,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {}

  @override
  void stopListening() {}

  @override
  void abort() {}

  @override
  void dispose() {
    _isListeningNotifier.dispose();
    _interimTranscriptNotifier.dispose();
    _errorNotifier.dispose();
  }
}
