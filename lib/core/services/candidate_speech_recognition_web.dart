// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'candidate_speech_recognition_service.dart';

CandidateSpeechRecognitionService getCandidateSpeechRecognitionService() {
  return WebCandidateSpeechRecognitionService();
}

class WebCandidateSpeechRecognitionService implements CandidateSpeechRecognitionService {
  html.SpeechRecognition? _recognition;
  bool _isListening = false;
  bool _isDisposed = false;

  final ValueNotifier<bool> _isListeningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _interimTranscriptNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> _errorNotifier = ValueNotifier<String?>(null);

  StreamSubscription? _startSub;
  StreamSubscription? _resultSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _endSub;

  @override
  bool get isSupported => html.SpeechRecognition.supported;

  @override
  bool get isListening => _isListening;

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
  }) {
    if (_isDisposed) return;
    if (!isSupported) {
      _errorNotifier.value = 'Speech recognition is not supported in this browser environment.';
      onError?.call('Speech recognition is not supported in this browser environment.');
      return;
    }

    try {
      stopListening();

      _recognition = html.SpeechRecognition()
        ..continuous = true
        ..interimResults = true
        ..lang = 'en-US';

      _startSub = _recognition!.onStart.listen((_) {
        if (_isDisposed) return;
        _isListening = true;
        _isListeningNotifier.value = true;
        _errorNotifier.value = null;
        onStart?.call();
      });

      _resultSub = _recognition!.onResult.listen((html.SpeechRecognitionEvent event) {
        if (_isDisposed) return;
        final results = event.results;
        if (results == null) return;

        String interimText = '';
        String finalText = '';

        for (int i = event.resultIndex ?? 0; i < results.length; i++) {
          final res = results[i];
          final item = res.item(0);
          final transcript = item.transcript?.trim() ?? '';
          if (transcript.isEmpty) continue;

          if (res.isFinal == true) {
            finalText = transcript;
          } else {
            interimText = transcript;
          }
        }

        if (interimText.isNotEmpty) {
          _interimTranscriptNotifier.value = interimText;
          onInterimResult(interimText);
        }

        if (finalText.isNotEmpty) {
          _interimTranscriptNotifier.value = '';
          onFinalResult(finalText);
        }
      });

      _errorSub = _recognition!.onError.listen((html.SpeechRecognitionError event) {
        if (_isDisposed) return;
        final err = event.error ?? 'Unknown recognition error';
        if (err == 'no-speech' || err == 'aborted') {
          return;
        }
        _errorNotifier.value = 'Microphone speech recognition notice: $err';
        onError?.call(err);
      });

      _endSub = _recognition!.onEnd.listen((_) {
        if (_isDisposed) return;
        _isListening = false;
        _isListeningNotifier.value = false;
        onEnd?.call();
      });

      _recognition!.start();
    } catch (e) {
      _isListening = false;
      _isListeningNotifier.value = false;
      _errorNotifier.value = 'Failed to start speech recognition: $e';
      onError?.call(e.toString());
    }
  }

  @override
  void stopListening() {
    try {
      _startSub?.cancel();
      _resultSub?.cancel();
      _errorSub?.cancel();
      _endSub?.cancel();
      _recognition?.stop();
    } catch (_) {}
    _isListening = false;
    _isListeningNotifier.value = false;
    _interimTranscriptNotifier.value = '';
  }

  @override
  void abort() {
    try {
      _recognition?.abort();
    } catch (_) {}
    stopListening();
  }

  @override
  void dispose() {
    _isDisposed = true;
    abort();
    _isListeningNotifier.dispose();
    _interimTranscriptNotifier.dispose();
    _errorNotifier.dispose();
  }
}
