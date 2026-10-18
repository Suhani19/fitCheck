import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Explicit audio lifecycle state for an interviewer turn.
enum TurnAudioState {
  pending, // Turn registered, awaiting speech output
  primarySpeaking, // Speaking via primary path (Agora Cloud Agent / WebRTC stream)
  fallbackSpeaking, // Speaking via fallback path (Browser Web Speech TTS)
  completed, // Turn audio playback has completed
  failed, // Audio playback failed (e.g. browser autoplay restriction)
}

/// Manages client-side browser speech synthesis when the Agora Conversational
/// Cloud Agent is deferred, unavailable, or in standby mode.
///
/// Enforces single-source-of-truth audio per turn:
/// - Primary (Agora) audio always takes precedence.
/// - Fallback browser TTS is only used when primary audio is confirmed unavailable.
/// - Fallback TTS plays at natural 1.0x rate (never slow 0.5x).
/// - Every turn is deduplicated with an explicit lifecycle state machine.
class InterviewSpeechService {
  final FlutterTts _tts;
  final Set<String> _spokenHashes = <String>{};
  final Map<String, TurnAudioState> _turnStates = <String, TurnAudioState>{};

  final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  bool _isInitialized = false;
  bool _isDisposed = false;
  String? _activeTurnId;

  InterviewSpeechService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _initTts();
  }

  bool get isSpeaking => isSpeakingNotifier.value;
  bool get isDisposed => _isDisposed;
  String? get activeTurnId => _activeTurnId;

  void _initTts() {
    try {
      _tts.setStartHandler(() {
        if (!_isDisposed) isSpeakingNotifier.value = true;
      });
      _tts.setCompletionHandler(() {
        if (!_isDisposed) {
          isSpeakingNotifier.value = false;
          if (_activeTurnId != null) {
            _turnStates[_activeTurnId!] = TurnAudioState.completed;
            _activeTurnId = null;
          }
        }
      });
      _tts.setCancelHandler(() {
        if (!_isDisposed) {
          isSpeakingNotifier.value = false;
          if (_activeTurnId != null) {
            if (_turnStates[_activeTurnId] == TurnAudioState.fallbackSpeaking) {
              _turnStates[_activeTurnId!] = TurnAudioState.pending;
            }
            _activeTurnId = null;
          }
        }
      });
      _tts.setErrorHandler((dynamic msg) {
        if (!_isDisposed) {
          isSpeakingNotifier.value = false;
          errorNotifier.value = msg?.toString() ?? 'Speech synthesis error';
          debugPrint('[InterviewSpeechService] Speech error: $msg');
          if (_activeTurnId != null) {
            _turnStates[_activeTurnId!] = TurnAudioState.failed;
            _activeTurnId = null;
          }
        }
      });
    } catch (e) {
      debugPrint('[InterviewSpeechService] Handler setup warning: $e');
    }
  }

  /// Initializes TTS with natural pacing (1.0 rate by default, NEVER 0.5).
  Future<void> initialize({String language = 'en-US', double rate = 1.0}) async {
    if (_isInitialized || _isDisposed) return;
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('[InterviewSpeechService] Initialization warning: $e');
    }
  }

  String _computeKey(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Returns the current TurnAudioState for the given turn identifier.
  TurnAudioState getTurnAudioState(String turnId) {
    return _turnStates[turnId] ?? TurnAudioState.pending;
  }

  /// Directly set a turn's audio state (e.g., when primary Agora stream takes over).
  void setTurnAudioState(String turnId, TurnAudioState state) {
    _turnStates[turnId] = state;
  }

  /// Marks a turn as being handled by the primary audio path (Agora WebRTC / Cloud Agent).
  /// Immediately stops any ongoing fallback TTS to prevent concurrent overlapping voices.
  Future<void> markPrimarySpeaking(String turnId, [String? text]) async {
    if (_activeTurnId != null && _activeTurnId != turnId) {
      await stop();
    } else if (isSpeaking) {
      await stop();
    }
    _turnStates[turnId] = TurnAudioState.primarySpeaking;
    if (text != null) {
      _spokenHashes.add(_computeKey(text));
    }
  }

  /// Marks a turn's primary audio as completed.
  void markPrimaryCompleted(String turnId, [String? text]) {
    _turnStates[turnId] = TurnAudioState.completed;
    if (text != null) {
      _spokenHashes.add(_computeKey(text));
    }
  }

  /// Returns true if this question text or turnId has already been spoken.
  bool hasSpoken(String text) {
    final key = _computeKey(text);
    return _spokenHashes.contains(key);
  }

  /// Returns true if the turn has already started speaking or completed.
  bool isTurnSpokenOrSpeaking(String turnId) {
    final s = getTurnAudioState(turnId);
    return s == TurnAudioState.primarySpeaking ||
        s == TurnAudioState.fallbackSpeaking ||
        s == TurnAudioState.completed;
  }

  /// Speaks the given interviewer turn via fallback browser TTS if not already spoken.
  ///
  /// If [force] is true, stops any existing playback and restarts speaking this turn.
  /// Returns true if speech was successfully dispatched.
  Future<bool> speakTurn({
    required String turnId,
    required String text,
    bool force = false,
  }) async {
    if (_isDisposed) return false;
    final clean = text.trim();
    if (clean.isEmpty) return false;

    final key = _computeKey(clean);
    final currentState = getTurnAudioState(turnId);

    if (!force) {
      if (currentState == TurnAudioState.primarySpeaking) {
        debugPrint('[InterviewSpeechService] Turn $turnId currently speaking via primary Agora, skipping fallback');
        return false;
      }
      if (currentState == TurnAudioState.fallbackSpeaking) {
        debugPrint('[InterviewSpeechService] Turn $turnId already speaking via fallback TTS, skipping duplicate');
        return false;
      }
      if (currentState == TurnAudioState.completed || _spokenHashes.contains(key)) {
        debugPrint('[InterviewSpeechService] Turn $turnId / question already completed, skipping: "$clean"');
        return false;
      }
    }

    // Stop any existing playback and clear previous active turn
    await stop();

    _activeTurnId = turnId;
    _turnStates[turnId] = TurnAudioState.fallbackSpeaking;
    _spokenHashes.add(key);

    if (!_isInitialized) {
      await initialize(rate: 1.0);
    }

    try {
      if (!_isDisposed) errorNotifier.value = null;
      final res = await _tts.speak(clean);
      final ok = res == 1 || res == true;
      if (!ok) {
        _spokenHashes.remove(key);
        _turnStates[turnId] = TurnAudioState.failed;
        _activeTurnId = null;
      }
      return ok;
    } catch (e) {
      _spokenHashes.remove(key);
      _turnStates[turnId] = TurnAudioState.failed;
      _activeTurnId = null;
      debugPrint('[InterviewSpeechService] Speak failed (e.g. browser autoplay restriction): $e');
      if (!_isDisposed) {
        errorNotifier.value = e.toString();
        isSpeakingNotifier.value = false;
      }
      return false;
    }
  }

  /// Legacy helper that delegates to [speakTurn] using a hash of the text.
  Future<bool> speakQuestion(String text, {bool force = false}) async {
    final key = _computeKey(text);
    return speakTurn(turnId: key, text: text, force: force);
  }

  /// Immediately interrupts and stops current speech playback.
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _tts.stop();
      if (!_isDisposed) isSpeakingNotifier.value = false;
      if (_activeTurnId != null) {
        if (_turnStates[_activeTurnId] == TurnAudioState.fallbackSpeaking) {
          _turnStates[_activeTurnId!] = TurnAudioState.pending;
        }
        _activeTurnId = null;
      }
    } catch (e) {
      debugPrint('[InterviewSpeechService] Stop error: $e');
    }
  }

  /// Resets spoken memory (e.g. when beginning a completely new session).
  void reset() {
    _spokenHashes.clear();
    _turnStates.clear();
    _activeTurnId = null;
    stop();
  }

  void dispose() {
    _isDisposed = true;
    try {
      _tts.stop();
    } catch (_) {}
    isSpeakingNotifier.dispose();
    errorNotifier.dispose();
  }
}
