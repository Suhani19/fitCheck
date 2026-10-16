import 'dart:async';
import 'package:flutter/material.dart';

import '../fitcheck/fitcheck_api_service.dart';
import '../fitcheck/live_interview_room_page.dart';
import 'agora_call_service.dart';
import 'call_sound_service.dart';
import 'runtime_api.dart';

enum CallStatus {
  idle,
  connecting,
  active,
  minimized,
  ending,
  ended,
  error,
}

enum ConversationState {
  idle,
  listening,
  thinking,
  speaking,
}

class CallSessionManager extends ChangeNotifier {
  static final CallSessionManager _instance = CallSessionManager._internal();
  static CallSessionManager get instance => _instance;

  CallSessionManager._internal();

  AgoraCallService _callService = AgoraCallService();
  RuntimeApi _runtimeApi = RuntimeApi();
  CallSoundService _soundService = CallSoundService();

  @visibleForTesting
  set callServiceForTesting(AgoraCallService service) {
    _callService = service;
  }

  @visibleForTesting
  set runtimeApiForTesting(RuntimeApi api) {
    _runtimeApi = api;
  }

  @visibleForTesting
  set soundServiceForTesting(CallSoundService service) {
    _soundService = service;
  }

  @visibleForTesting
  void setStateForTesting({
    FitCheckInterviewer? interviewer,
    FitCheckSession? fitCheckSession,
    String? difficulty,
    String? jobTitle,
    CallStatus? status,
    int? seconds,
    bool? interviewerSpeaking,
    bool? interviewerPresent,
    ConversationState? conversationState,
    String? currentEmotion,
    double? emotionIntensity,
    double? remoteAudioLevel,
  }) {
    if (interviewer != null) _activeInterviewer = interviewer;
    if (fitCheckSession != null) _activeFitCheckSession = fitCheckSession;
    if (difficulty != null) _activeDifficulty = difficulty;
    if (jobTitle != null) _activeJobTitle = jobTitle;
    if (status != null) _status = status;
    if (seconds != null) _callSeconds = seconds;
    if (interviewerSpeaking != null) _interviewerSpeaking = interviewerSpeaking;
    if (interviewerPresent != null) _interviewerPresent = interviewerPresent;
    if (conversationState != null) _conversationState = conversationState;
    if (currentEmotion != null) _currentEmotion = currentEmotion;
    if (emotionIntensity != null) _emotionIntensity = emotionIntensity;
    if (remoteAudioLevel != null) _remoteAudioLevel = remoteAudioLevel;
    notifyListeners();
  }

  @visibleForTesting
  void setStatusForTesting(CallStatus status, {String? reason}) {
    _setStatus(status, reason: reason);
  }

  @visibleForTesting
  void setEmotionForTesting({required String emotion, required double intensity}) {
    _currentEmotion = emotion;
    _emotionIntensity = intensity;
    notifyListeners();
  }

  @visibleForTesting
  void setConversationStateForTesting(ConversationState state) {
    _setConversationState(state);
  }

  @visibleForTesting
  void resetForTesting() {
    _stopCallTimer();
    _soundService.stopAll();
    _soundService = CallSoundService();
    _status = CallStatus.idle;
    _conversationState = ConversationState.idle;
    _currentEmotion = 'neutral';
    _emotionIntensity = 0.35;
    _remoteAudioLevel = 0.0;
    _activeInterviewer = null;
    _activeFitCheckSession = null;
    _activeCandidate = null;
    _apiService = null;
    _onInterviewEnded = null;
    _activeJobTitle = null;
    _activeDifficulty = null;
    onRestoreRoute = null;
    _currentSession = null;
    _transcriptBuffer.clear();
    _callSeconds = 0;
    _interviewerPresent = false;
    _interviewerSpeaking = false;
    _userSpeaking = false;
    _errorMessage = null;
    _hasPlayedConnectedSound = false;
    notifyListeners();
  }

  AgoraCallService get callService => _callService;
  RuntimeApi get runtimeApi => _runtimeApi;
  CallSoundService get soundService => _soundService;

  FitCheckInterviewer? _activeInterviewer;
  FitCheckSession? _activeFitCheckSession;
  FitCheckCandidate? _activeCandidate;
  FitCheckApiService? _apiService;
  void Function(FitCheckSession session)? _onInterviewEnded;
  String? _activeJobTitle;
  String? _activeDifficulty;
  void Function(BuildContext context)? onRestoreRoute;

  RuntimeSession? _currentSession;
  CallStatus _status = CallStatus.idle;
  ConversationState _conversationState = ConversationState.idle;
  String _currentEmotion = 'neutral';
  double _emotionIntensity = 0.35;
  double _remoteAudioLevel = 0.0;

  bool _interviewerPresent = false;
  bool _interviewerSpeaking = false;
  bool _userSpeaking = false;
  bool _micEnabled = true;
  String? _errorMessage;

  Timer? _callTimer;
  int _callSeconds = 0;

  bool _hasPlayedConnectedSound = false;
  bool get hasPlayedConnectedSound => _hasPlayedConnectedSound;

  final List<Map<String, String>> _transcriptBuffer = [];

  FitCheckInterviewer? get activeInterviewer => _activeInterviewer;
  FitCheckSession? get activeFitCheckSession => _activeFitCheckSession;
  FitCheckCandidate? get activeCandidate => _activeCandidate;
  String? get activeDifficulty => _activeDifficulty ?? _activeFitCheckSession?.difficulty;
  String? get activeJobTitle => _activeJobTitle;

  RuntimeSession? get currentSession => _currentSession;
  CallStatus get status => _status;
  ConversationState get conversationState => _conversationState;
  String get currentEmotion => _currentEmotion;
  double get emotionIntensity => _emotionIntensity;
  double get remoteAudioLevel => _remoteAudioLevel;

  void _setConversationState(ConversationState newState) {
    if (_conversationState == newState) return;
    _conversationState = newState;
    debugPrint('[CONVERSATION] state=${newState.name}');
    notifyListeners();
  }

  bool get isCallActive =>
      _status == CallStatus.connecting ||
      _status == CallStatus.active ||
      _status == CallStatus.minimized;
  bool get hasActiveCall => isCallActive;
  String? get activeInterviewerId => _activeInterviewer?.id;
  String? get activeInterviewerName => _activeInterviewer?.name;
  bool get isMinimized => _status == CallStatus.minimized;
  bool get isConnected =>
      _status == CallStatus.active || _status == CallStatus.minimized;

  bool isInterviewerOnCall(String interviewerId) {
    return hasActiveCall &&
        (_activeInterviewer?.id == interviewerId || _activeFitCheckSession?.interviewerId == interviewerId);
  }

  bool get interviewerPresent => _interviewerPresent;
  bool get interviewerSpeaking => _interviewerSpeaking;
  bool get userSpeaking => _userSpeaking;
  bool get micEnabled => _micEnabled;
  String? get errorMessage => _errorMessage;
  int get callSeconds => _callSeconds;

  String get formattedCallTime {
    final minutes = _callSeconds ~/ 60;
    final seconds = _callSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _callGeneration = 0;

  void _setStatus(CallStatus newStatus, {String? reason}) {
    if (_status == newStatus) return;

    // Hard guard against illegal transitions during or after teardown:
    if (_status == CallStatus.ending &&
        (newStatus == CallStatus.connecting ||
            newStatus == CallStatus.active ||
            newStatus == CallStatus.minimized)) {
      debugPrint(
        '[CALL] Rejected illegal status transition $_status -> $newStatus${reason != null ? " ($reason)" : ""}',
      );
      return;
    }

    if (_status == CallStatus.ended &&
        (newStatus == CallStatus.connecting ||
            newStatus == CallStatus.active ||
            newStatus == CallStatus.minimized ||
            newStatus == CallStatus.ending)) {
      debugPrint(
        '[CALL] Rejected illegal status transition $_status -> $newStatus${reason != null ? " ($reason)" : ""}',
      );
      return;
    }

    _status = newStatus;
    debugPrint('[CALL] status -> ${newStatus.name}');

    // Audio cue transitions
    switch (newStatus) {
      case CallStatus.connecting:
        _soundService.playConnecting();
        break;
      case CallStatus.active:
        _soundService.stopConnecting();
        if (!_hasPlayedConnectedSound) {
          _hasPlayedConnectedSound = true;
          _soundService.playConnected();
        }
        break;
      case CallStatus.ending:
        _soundService.stopConnecting();
        _soundService.playCallEnded();
        break;
      case CallStatus.ended:
      case CallStatus.idle:
        _soundService.stopConnecting();
        break;
      case CallStatus.error:
        _soundService.stopAll();
        break;
      case CallStatus.minimized:
        break;
    }

    notifyListeners();
  }

  Future<void> startCall(FitCheckInterviewer interviewer, {String? appIdOverride}) async {
    debugPrint('[CALL] start requested');
    if (_status == CallStatus.ending || _status == CallStatus.ended) {
      debugPrint('[CALL] startCall rejected: status is $_status');
      return;
    }

    if (isCallActive) {
      if (_activeInterviewer?.id == interviewer.id) {
        if (_status == CallStatus.minimized) {
          _setStatus(CallStatus.active, reason: 'un-minimized');
        }
        return;
      } else {
        await endCall();
      }
    }

    final int generation = ++_callGeneration;

    _activeInterviewer = interviewer;
    _errorMessage = null;
    _callSeconds = 0;
    _interviewerPresent = false;
    _interviewerSpeaking = false;
    _userSpeaking = false;
    _micEnabled = true;
    _hasPlayedConnectedSound = false;
    _transcriptBuffer.clear();

    _setStatus(CallStatus.connecting);

    try {
      final session = await _runtimeApi.createSession(interviewerId: interviewer.id);

      if (generation != _callGeneration ||
          _status == CallStatus.ending ||
          _status == CallStatus.ended ||
          _status == CallStatus.idle) {
        debugPrint('[CALL] startCall aborted after createSession');
        try {
          unawaited(_runtimeApi.endSession(sessionId: session.sessionId, transcript: []));
        } catch (_) {}
        return;
      }

      _currentSession = session;

      final effectiveAppId = (appIdOverride != null && appIdOverride.isNotEmpty)
          ? appIdOverride
          : session.appId;

      if (effectiveAppId.isEmpty) {
        throw Exception(
          'Agora App ID not configured. Set AGORA_APP_ID in backend or build config.',
        );
      }

      await _callService.join(
        appId: effectiveAppId,
        token: session.rtcToken,
        channel: session.channel,
        uid: session.uid,
        onJoined: () {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          debugPrint('[CALL] Agora connection established');
          if (_interviewerPresent) {
            _startCallTimer();
            _setStatus(CallStatus.active, reason: 'channel joined and interviewer already present');
          }
        },
        onRemoteUserJoined: (remoteUid) {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          debugPrint('[CALL] agent/user joined: remoteUid=$remoteUid');
          _interviewerPresent = true;
          _startCallTimer();
          _setStatus(CallStatus.active, reason: 'agent joined');
        },
        onRemoteUserLeft: (remoteUid) {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          debugPrint('[CALL] agent/user left: remoteUid=$remoteUid');
          _interviewerPresent = false;
          notifyListeners();
        },
        onAudioVolume: ({required int uid, required int volume}) {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          if (uid == 0 || uid == session.uid) {
            final isSpeaking = volume > 8;
            if (_userSpeaking != isSpeaking) {
              _userSpeaking = isSpeaking;
              if (isSpeaking) {
                _setConversationState(ConversationState.listening);
              } else if (!_interviewerSpeaking) {
                _setConversationState(ConversationState.thinking);
              }
              notifyListeners();
            }
          } else {
            if (!_interviewerPresent || _status == CallStatus.connecting) {
              debugPrint('[CALL] agent/user joined via volume detection: remoteUid=$uid');
              _interviewerPresent = true;
              _startCallTimer();
              _setStatus(CallStatus.active, reason: 'remote audio volume');
            }
            final isSpeaking = volume > 8;
            _remoteAudioLevel = (volume / 100.0).clamp(0.0, 1.0);
            if (_interviewerSpeaking != isSpeaking) {
              _interviewerSpeaking = isSpeaking;
              if (isSpeaking) {
                _setConversationState(ConversationState.speaking);
              } else {
                _remoteAudioLevel = 0.0;
                _setConversationState(ConversationState.listening);
              }
              notifyListeners();
            }
          }
        },
        onTranscriptTurn: (role, text) {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          if (role == 'assistant' && (!_interviewerPresent || _status == CallStatus.connecting)) {
            debugPrint('[CALL] agent/user joined via transcript turn');
            _interviewerPresent = true;
            _startCallTimer();
            _setStatus(CallStatus.active, reason: 'assistant transcript');
          }
          recordTranscriptTurn(role, text);
        },
        onError: (message) {
          if (generation != _callGeneration ||
              _status == CallStatus.ending ||
              _status == CallStatus.ended ||
              _status == CallStatus.idle) {
            return;
          }
          _errorMessage = message;
          _setStatus(CallStatus.error, reason: message);
        },
      );
    } catch (e) {
      if (generation != _callGeneration ||
          _status == CallStatus.ending ||
          _status == CallStatus.ended ||
          _status == CallStatus.idle) {
        return;
      }
      _errorMessage = e.toString();
      _setStatus(CallStatus.error, reason: e.toString());
      rethrow;
    }
  }

  String detectLanguage(String text) {
    if (text.isEmpty) return 'english';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hindi';
    final lower = text.toLowerCase();
    final hinglishWords = [
      'haan', 'nahi', 'nahin', 'kya', 'kyu', 'kyun', 'kaise', 'bhai', 'yaar',
      'accha', 'achha', 'theek', 'thik', 'bol', 'bolo', 'karo', 'karenge',
      'raha', 'rahe', 'hai', 'hain', 'hota', 'hoti', 'waise', 'aaj', 'kal',
      'abhi', 'sahi', 'matlab', 'arrey', 'arey', 'batao', 'chal', 'chalo',
      'meri', 'mera', 'apna', 'hum', 'tum'
    ];
    final words = lower.split(RegExp(r'\s+'));
    int matchCount = 0;
    for (final w in words) {
      final clean = w.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (hinglishWords.contains(clean)) {
        matchCount++;
      }
    }
    if (matchCount >= 2 || (words.isNotEmpty && matchCount / words.length >= 0.15)) {
      return 'hinglish';
    }
    return 'english';
  }

  void _processTurnEmotion(String text, String role) {
    final lower = text.toLowerCase();
    final prev = _currentEmotion;
    String detected = 'neutral';
    double rawIntensity = 0.35;
    String reason = 'normal_conversation';

    if (RegExp(r'\b(shut up|stupid|idiot|hate you|liar|useless|annoying|wrong|rubbish)\b').hasMatch(lower)) {
      detected = 'defensive';
      rawIntensity = 0.80;
      reason = 'hostile_or_conflict_interaction';
    } else if (RegExp(r'\b(sad|crying|depressed|grief|lost my|passed away|died|broken|funeral|heartbroken|awful|miserable|lonely|feeling down|hopeless|failed)\b').hasMatch(lower)) {
      detected = 'sad';
      rawIntensity = 0.75;
      reason = 'sad_situation_or_loss';
    } else if (RegExp(r'\b(got the job|promoted|promotion|won|celebrate|celebrating|huge news|finally|passed|accepted|congratulations|we did it|dream come true|nailed it|thrilled|super excited)\b').hasMatch(lower)) {
      detected = 'excited';
      rawIntensity = 0.85;
      reason = 'positive_user_achievement';
    } else if (RegExp(r'\b(haha|hahaha|lol|lmao|funny|hilarious|cracking up|joke|prank|ridiculous|rofl|bizarre)\b').hasMatch(lower)) {
      detected = 'amused';
      rawIntensity = 0.70;
      reason = 'funny_situation_or_banter';
    } else if (RegExp(r'\b(happy|glad|wonderful|good news|love this|great day|awesome|feeling good|blessed|thank you so much|appreciate)\b').hasMatch(lower)) {
      detected = 'happy';
      rawIntensity = 0.65;
      reason = 'warm_positive_interaction';
    }

    if (detected != 'neutral') {
      double intensity = rawIntensity;
      final interviewer = _activeInterviewer;
      if (interviewer != null) {
        if (detected == 'amused' && interviewer.questioningStyle == 'conversational') {
          intensity = (intensity + 0.12).clamp(0.0, 1.0);
        } else if (detected == 'defensive' && interviewer.questioningStyle == 'challenging') {
          intensity = (intensity + 0.15).clamp(0.0, 1.0);
        }
      }
      if (detected == prev) {
        intensity = (_emotionIntensity + 0.15).clamp(0.0, 1.0);
        reason = 'reinforced_$detected';
      }
      _currentEmotion = detected;
      _emotionIntensity = double.parse(intensity.toStringAsFixed(2));
    } else {
      if (_currentEmotion != 'neutral') {
        final decayed = _emotionIntensity - 0.18;
        if (decayed > 0.25) {
          _emotionIntensity = double.parse(decayed.toStringAsFixed(2));
          reason = 'decay_$_currentEmotion';
        } else {
          _currentEmotion = 'neutral';
          _emotionIntensity = 0.35;
          reason = 'settled_to_neutral';
        }
      }
    }

    debugPrint(
      '[EMOTION] previous=$prev detected=$_currentEmotion intensity=${_emotionIntensity.toStringAsFixed(2)} reason=$reason transition=$prev->$_currentEmotion',
    );
    notifyListeners();
  }

  void recordTranscriptTurn(String role, String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      _transcriptBuffer.add({'role': role, 'text': trimmed});

      // M6.15 Language logging
      final lang = detectLanguage(trimmed);
      debugPrint('[LANGUAGE] detected=$lang response=$lang');

      // M6.2 & M6.3 Emotion processing
      _processTurnEmotion(trimmed, role);
    }
  }

  /// Attaches or updates an active FitCheck live interview session.
  /// Prevents duplicate session creation, stale session reuse, and double disposal.
  void attachFitCheckSession({
    required FitCheckSession session,
    required FitCheckInterviewer interviewer,
    FitCheckCandidate? candidate,
    FitCheckApiService? apiService,
    void Function(FitCheckSession session)? onInterviewEnded,
    String? jobTitle,
    String? difficulty,
  }) {
    if (_status == CallStatus.ending || _status == CallStatus.ended) {
      debugPrint('[CALL] attachFitCheckSession rejected: status is $_status');
      return;
    }

    if (_activeFitCheckSession?.id == session.id && isCallActive) {
      debugPrint('[CALL] FitCheck session ${session.id} already active; refreshing references');
      _activeInterviewer = interviewer;
      _activeCandidate = candidate ?? _activeCandidate;
      _apiService = apiService ?? _apiService;
      _onInterviewEnded = onInterviewEnded ?? _onInterviewEnded;
      if (jobTitle != null) _activeJobTitle = jobTitle;
      if (difficulty != null) _activeDifficulty = difficulty;
      if (_status == CallStatus.minimized) {
        _setStatus(CallStatus.active, reason: 'un-minimized');
      }
      return;
    }

    if (isCallActive) {
      debugPrint('[CALL] Concluding previous call before attaching new session ${session.id}');
      _stopCallTimer();
      _callGeneration++;
    }

    _callGeneration++;
    _activeFitCheckSession = session;
    _activeInterviewer = interviewer;
    _activeCandidate = candidate;
    _apiService = apiService;
    _onInterviewEnded = onInterviewEnded;
    _activeJobTitle = jobTitle;
    _activeDifficulty = difficulty ?? session.difficulty;
    _errorMessage = null;
    _callSeconds = 0;
    _interviewerPresent = false;
    _interviewerSpeaking = false;
    _userSpeaking = false;
    _micEnabled = true;
    _hasPlayedConnectedSound = false;
    _transcriptBuffer.clear();

    _setStatus(CallStatus.connecting);
  }

  void notifyAgoraConnected() {
    _interviewerPresent = true;
    _startCallTimer();
    _setStatus(CallStatus.active, reason: 'agora connected');
  }

  void notifySpeakingState({
    bool? interviewerSpeaking,
    bool? candidateSpeaking,
    double? remoteLevel,
  }) {
    bool changed = false;
    if (interviewerSpeaking != null && _interviewerSpeaking != interviewerSpeaking) {
      _interviewerSpeaking = interviewerSpeaking;
      changed = true;
      if (interviewerSpeaking) {
        _setConversationState(ConversationState.speaking);
      } else {
        _setConversationState(ConversationState.listening);
      }
    }
    if (candidateSpeaking != null && _userSpeaking != candidateSpeaking) {
      _userSpeaking = candidateSpeaking;
      changed = true;
      if (candidateSpeaking) {
        _setConversationState(ConversationState.listening);
      } else if (!_interviewerSpeaking) {
        _setConversationState(ConversationState.thinking);
      }
    }
    if (remoteLevel != null) {
      _remoteAudioLevel = remoteLevel;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void minimize() {
    if (isCallActive) {
      _setStatus(CallStatus.minimized);
    }
  }

  void restore(BuildContext context) {
    if (!isCallActive || _activeInterviewer == null) return;
    _setStatus(CallStatus.active, reason: 'restore');

    // 1. Prioritize Shell route callback if registered (avoids pushing duplicate routes)
    if (onRestoreRoute != null) {
      onRestoreRoute!(context);
      return;
    }

    // 2. If active FitCheck session exists, restore FitCheckLiveInterviewRoom
    if (_activeFitCheckSession != null && _activeInterviewer != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FitCheckLiveInterviewRoom(
            session: _activeFitCheckSession!,
            interviewer: _activeInterviewer!,
            candidate: _activeCandidate,
            apiService: _apiService ?? FitCheckApiService(),
            onInterviewEnded: (ended) {
              _onInterviewEnded?.call(ended);
              endCall();
            },
          ),
        ),
      );
    }
  }

  Future<void> toggleMic() async {
    final next = !_micEnabled;
    await _callService.setMicEnabled(next);
    _micEnabled = next;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    await _callService.setSpeakerphoneEnabled(true);
  }

  Future<void> setMicEnabled(bool enabled) async {
    await _callService.setMicEnabled(enabled);
    _micEnabled = enabled;
    notifyListeners();
  }

  Future<void> endCall() async {
    debugPrint('[CALL] end requested');
    if (_status == CallStatus.idle ||
        _status == CallStatus.ending ||
        _status == CallStatus.ended) {
      debugPrint('[CALL] endCall ignored: status is already $_status');
      return;
    }

    _callGeneration++;
    _stopCallTimer();
    _setStatus(CallStatus.ending);

    final session = _currentSession;
    final fitCheckSession = _activeFitCheckSession;
    final apiService = _apiService;
    final onInterviewEnded = _onInterviewEnded;
    final turns = List<Map<String, String>>.from(_transcriptBuffer);

    // Agora leave is performed asynchronously so local end sound and UI teardown
    // never block or wait on Agora RTC engine or callbacks.
    debugPrint('[AGORA] leave requested');
    unawaited(() async {
      try {
        await _callService.leave();
      } catch (e) {
        debugPrint('[AGORA] leave error: $e');
      }
      debugPrint('[AGORA] leave completed');
    }());

    _setStatus(CallStatus.ended);
    _setStatus(CallStatus.idle);

    _activeInterviewer = null;
    _activeFitCheckSession = null;
    _activeCandidate = null;
    _apiService = null;
    _onInterviewEnded = null;
    _activeJobTitle = null;
    _activeDifficulty = null;
    _currentSession = null;
    _transcriptBuffer.clear();
    _callSeconds = 0;
    _interviewerPresent = false;
    _interviewerSpeaking = false;
    _userSpeaking = false;
    notifyListeners();

    if (session != null) {
      debugPrint('[SESSION] backend end requested');
      unawaited(() async {
        try {
          await _runtimeApi.endSession(
            sessionId: session.sessionId,
            transcript: turns,
          );
          debugPrint('[SESSION] backend end completed');
        } catch (e) {
          debugPrint('[SESSION] backend end error: $e');
        }
      }());
    }

    if (fitCheckSession != null && apiService != null) {
      debugPrint('[FITCHECK] backend end requested');
      unawaited(() async {
        try {
          final ended = await apiService.endSession(
            fitCheckSession.id,
            transcript: turns,
          );
          onInterviewEnded?.call(ended);
          debugPrint('[FITCHECK] backend end completed');
        } catch (e) {
          debugPrint('[FITCHECK] backend end error: $e');
        }
      }());
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callSeconds++;
      notifyListeners();
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }
}
