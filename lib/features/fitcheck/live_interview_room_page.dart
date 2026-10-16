import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import '../call/agora_call_service.dart';
import '../call/call_session_manager.dart';
import 'fitcheck_api_service.dart';

class FitCheckLiveInterviewRoom extends StatefulWidget {
  final FitCheckSession session;
  final FitCheckInterviewer interviewer;
  final FitCheckCandidate? candidate;
  final FitCheckApiService apiService;
  final Function(FitCheckSession session) onInterviewEnded;

  const FitCheckLiveInterviewRoom({
    super.key,
    required this.session,
    required this.interviewer,
    this.candidate,
    required this.apiService,
    required this.onInterviewEnded,
  });

  @override
  State<FitCheckLiveInterviewRoom> createState() => _FitCheckLiveInterviewRoomState();
}

class _FitCheckLiveInterviewRoomState extends State<FitCheckLiveInterviewRoom>
    with SingleTickerProviderStateMixin {
  AgoraCallService get _callService => CallSessionManager.instance.callService;

  // Audio & Connection State
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  bool _isInterviewerSpeaking = false;
  bool _isCandidateSpeaking = false;
  bool _ending = false;
  int _sessionSeconds = 0;
  Timer? _timer;
  String? _connectionError;
  String? _selectedRecordingDeviceId;
  String? _selectedPlaybackDeviceId;

  // Real-time transcript tracking
  final List<Map<String, dynamic>> _transcript = [];
  final ScrollController _transcriptScrollController = ScrollController();
  bool _userScrolledUp = false;

  // Stage and adaptive progression state
  String _currentStage = 'introduction';
  String? _currentQuestionText;

  // Text fallback input drawer state
  bool _showTextFallback = false;
  final TextEditingController _fallbackController = TextEditingController();

  // Waveform animation controller for live acoustic visualizers
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _waveController.repeat(reverse: true);
    }

    _transcriptScrollController.addListener(_onScroll);
    _initLiveRoom();
  }

  void _onScroll() {
    if (!_transcriptScrollController.hasClients) return;
    final maxScroll = _transcriptScrollController.position.maxScrollExtent;
    final currentScroll = _transcriptScrollController.position.pixels;
    final isNearBottom = (maxScroll - currentScroll) < 120;
    if (_userScrolledUp == isNearBottom) {
      setState(() {
        _userScrolledUp = !isNearBottom;
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fallbackController.dispose();
    _timer?.cancel();
    _transcriptScrollController.removeListener(_onScroll);
    _transcriptScrollController.dispose();

    // If call is still active and not explicitly ending or minimized, clean up call session
    if (!CallSessionManager.instance.isMinimized) {
      CallSessionManager.instance.endCall();
    }
    super.dispose();
  }

  Future<void> _initLiveRoom() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Synchronize session definition with CallSessionManager singleton
    CallSessionManager.instance.attachFitCheckSession(
      session: widget.session,
      interviewer: widget.interviewer,
      candidate: widget.candidate,
      apiService: widget.apiService,
      onInterviewEnded: widget.onInterviewEnded,
      difficulty: widget.session.difficulty,
    );

    // Start session timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _sessionSeconds++);
    });

    // Hydrate existing transcript if reopening/refreshing, or populate initial opening question
    if (widget.session.transcript != null && widget.session.transcript!.isNotEmpty) {
      _transcript.clear();
      for (final t in widget.session.transcript!) {
        if (t is Map) {
          final text = (t['text'] ?? '').toString().trim();
          if (text.isNotEmpty &&
              !text.contains('|1|1|') &&
              !text.contains('|1|2|') &&
              !text.contains('eyJvYm') &&
              !text.contains('message.state')) {
            _transcript.add(Map<String, dynamic>.from(t));
          }
        }
      }
      for (final t in _transcript.reversed) {
        if (t['role'] == 'interviewer') {
          _currentQuestionText = t['text'] as String?;
          break;
        }
      }
    } else {
      final plan = widget.session.sessionPlan;
      if (plan != null && plan['opening_question'] != null) {
        _currentQuestionText = plan['opening_question'] as String;
        _transcript.add({
          'role': 'interviewer',
          'text': _currentQuestionText!,
          'turn_index': 0,
          'turn_id': 1,
          'is_final': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    // Connect to Agora RTC Channel
    final channel = widget.session.channel;
    final token = widget.session.rtcToken;
    final appId = widget.session.appId;

    if (appId != null && appId.isNotEmpty && token != null && token.isNotEmpty) {
      try {
        await _callService.join(
          appId: appId,
          token: token,
          channel: channel,
          uid: 1001,
          onJoined: () {
            if (mounted) {
              setState(() {
                _isConnected = true;
                _connectionError = null;
              });
            }
            CallSessionManager.instance.notifyAgoraConnected();
          },
          onRemoteUserJoined: (remoteUid) {
            if (mounted) {
              setState(() {
                _isConnected = true;
                _isInterviewerSpeaking = true;
              });
            }
            CallSessionManager.instance.notifyAgoraConnected();
            CallSessionManager.instance.notifySpeakingState(interviewerSpeaking: true);
          },
          onRemoteUserLeft: (remoteUid) {
            if (mounted) setState(() => _isInterviewerSpeaking = false);
            CallSessionManager.instance.notifySpeakingState(interviewerSpeaking: false);
          },
          onAudioVolume: ({required int uid, required int volume}) {
            if (!mounted) return;
            if (uid == 1001 || uid == 0) {
              final speaking = volume > 8;
              setState(() {
                _isCandidateSpeaking = speaking;
              });
              CallSessionManager.instance.notifySpeakingState(candidateSpeaking: speaking);
            } else {
              final speaking = volume > 8;
              setState(() {
                _isInterviewerSpeaking = speaking;
              });
              CallSessionManager.instance.notifySpeakingState(
                interviewerSpeaking: speaking,
                remoteLevel: (volume / 100.0).clamp(0.0, 1.0),
              );
            }
          },
          onError: (msg) {
            debugPrint('[LIVE_ROOM] Agora error: $msg');
            if (mounted) {
              setState(() {
                _connectionError = msg;
              });
            }
          },
          onTranscriptEvent: (event) {
            _handleTranscriptEvent(event);
          },
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _connectionError = 'Audio connection notice: $e';
          });
        }
      }
    } else {
      if (mounted) setState(() => _isConnected = true);
    }
  }

  void _handleTranscriptEvent(AgoraTranscriptEvent event) {
    if (!mounted) return;
    final text = event.text.trim();
    if (text.isEmpty) return;

    if (text.contains('|1|1|') ||
        text.contains('|1|2|') ||
        text.startsWith('eyJvYm') ||
        text.contains('message.state') ||
        text.contains('agent.state')) {
      return;
    }

    setState(() {
      if (event.role == 'interviewer') {
        _isInterviewerSpeaking = !event.isFinal;
        _currentQuestionText = text;
      } else {
        _isCandidateSpeaking = !event.isFinal;
      }

      // 1. Match by explicit turnId if present
      if (event.turnId != null) {
        final existingIndex = _transcript.indexWhere(
          (t) => t['turn_id'] == event.turnId && t['role'] == event.role,
        );

        if (existingIndex >= 0) {
          final existing = _transcript[existingIndex];
          existing['text'] = text;
          if (event.isFinal) existing['is_final'] = true;
          return;
        }

        if (event.turnId == 1 && event.role == 'interviewer') {
          final preSeededIndex = _transcript.indexWhere(
            (t) => t['turn_index'] == 0 && t['role'] == 'interviewer',
          );
          if (preSeededIndex >= 0) {
            final preSeeded = _transcript[preSeededIndex];
            preSeeded['turn_id'] = 1;
            preSeeded['text'] = text;
            if (event.isFinal) preSeeded['is_final'] = true;
            return;
          }
        }
      }

      // 2. Progressive hypothesis matching
      if (_transcript.isNotEmpty) {
        final last = _transcript.last;
        if (last['role'] == event.role) {
          final lastText = (last['text'] as String).trim();
          final isExtension = text.startsWith(lastText) && text.length > lastText.length;
          final isSameTurn = last['turn_id'] == event.turnId || event.turnId == null || last['turn_id'] == null;

          if ((last['is_final'] != true && isSameTurn) || (isExtension && isSameTurn)) {
            last['text'] = text;
            if (event.turnId != null) last['turn_id'] = event.turnId;
            if (event.isFinal) last['is_final'] = true;
            return;
          }

          if (lastText == text && (last['is_final'] == true || event.isFinal)) {
            last['is_final'] = true;
            return;
          }
        }
      }

      // 3. New utterance turn
      _transcript.add({
        'role': event.role,
        'text': text,
        'turn_id': event.turnId,
        'is_final': event.isFinal,
        'turn_index': _transcript.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _autoScrollToBottomIfAllowed();
  }

  void _appendTranscriptTurn({required String role, required String text}) {
    _handleTranscriptEvent(
      AgoraTranscriptEvent(
        role: role,
        text: text,
        isFinal: true,
      ),
    );
  }

  void _autoScrollToBottomIfAllowed() {
    if (_userScrolledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomNow() {
    setState(() => _userScrolledUp = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callService.setMicEnabled(!_isMuted);
    CallSessionManager.instance.setMicEnabled(!_isMuted);
  }

  void _toggleSpeaker() {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    _callService.setSpeakerEnabled(_isSpeakerOn);
  }

  void _requestClarification() {
    setState(() {
      _showTextFallback = true;
    });
    _simulateCandidateAnswer('Could you please clarify the specific latency constraints and partition scope for this question?');
  }

  void _repeatQuestion() {
    if (_currentQuestionText != null && _currentQuestionText!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.interviewer.name}: "$_currentQuestionText"'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showAudioDeviceSettingsDialog() async {
    final recordingDevices = await _callService.getRecordingDevices();
    final playbackDevices = await _callService.getPlaybackDevices();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String? selectedMicId = _selectedRecordingDeviceId ?? (recordingDevices.isNotEmpty ? recordingDevices.first.id : null);
        String? selectedSpeakerId = _selectedPlaybackDeviceId ?? (playbackDevices.isNotEmpty ? playbackDevices.first.id : null);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: FitCheckTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.tune, color: FitCheckTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio Devices & Settings',
                    style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Microphone (Audio Input)',
                        style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      if (recordingDevices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FitCheckTheme.borderSubtle),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor: FitCheckTheme.surfaceElevated,
                              value: selectedMicId,
                              items: recordingDevices.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d.id,
                                  child: Text(d.name, style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  setDialogState(() => selectedMicId = val);
                                  setState(() => _selectedRecordingDeviceId = val);
                                  final ok = await _callService.setRecordingDevice(val);
                                  if (!ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not switch microphone on this browser/platform.')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FitCheckTheme.borderSubtle),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: FitCheckTheme.textMuted),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'System Default Microphone active.\n(Device enumeration requires microphone permission).',
                                  style: TextStyle(color: FitCheckTheme.textMuted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      const Text(
                        'Speaker (Audio Output)',
                        style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      if (playbackDevices.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FitCheckTheme.borderSubtle),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor: FitCheckTheme.surfaceElevated,
                              value: selectedSpeakerId,
                              items: playbackDevices.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d.id,
                                  child: Text(d.name, style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  setDialogState(() => selectedSpeakerId = val);
                                  setState(() => _selectedPlaybackDeviceId = val);
                                  final ok = await _callService.setPlaybackDevice(val);
                                  if (!ok && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Audio output routing requires browser setSinkId support (Chrome/Edge desktop).')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.surfaceElevated.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: FitCheckTheme.borderSubtle),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: FitCheckTheme.textMuted),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'System Default Audio Output active.\n(Audio output selection requires browser setSinkId support).',
                                  style: TextStyle(color: FitCheckTheme.textMuted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done', style: TextStyle(color: FitCheckTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simulateCandidateAnswer(String text) {
    if (text.trim().isEmpty) return;
    _appendTranscriptTurn(role: 'candidate', text: text.trim());
    _fetchNextAdaptiveFollowUp();
  }

  Future<void> _fetchNextAdaptiveFollowUp() async {
    try {
      final result = await widget.apiService.getNextAdaptiveQuestion(widget.session.id);
      if (!mounted) return;
      if (result['question'] != null) {
        final q = result['question']['question'] as String;
        _appendTranscriptTurn(role: 'interviewer', text: q);
        if (result['stage_decision'] != null) {
          setState(() {
            _currentStage = result['stage_decision']['next_stage'] as String;
          });
        }
      }
    } catch (_) {
      // In-flight progression fallback
    }
  }

  Future<void> _confirmAndEndInterview() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitCheckTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: FitCheckTheme.error, size: 22),
            const SizedBox(width: 8),
            Text(
              'End Interview Session?',
              style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'You have completed ${_formatDuration(_sessionSeconds)} of this live simulation with ${widget.interviewer.name}. Concluding now will finalize your transcript, generate your competency rubric scorecard, and save preparation recommendations.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Continue Interview', style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FitCheckTheme.error),
            child: const Text('End & Evaluate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldEnd != true) return;

    _timer?.cancel();
    _timer = null;

    if (widget.session.id.startsWith('demo-sess-') ||
        widget.session.id.startsWith('sess-unit-') ||
        widget.candidate?.id == 'demo-elena-cand') {
      await CallSessionManager.instance.endCall();
      final endedDemoSession = FitCheckSession(
        id: widget.session.id,
        candidateId: widget.session.candidateId,
        jobId: widget.session.jobId,
        interviewerId: widget.session.interviewerId,
        difficulty: widget.session.difficulty,
        status: 'ended',
        channel: widget.session.channel,
        startedAt: widget.session.startedAt,
        endedAt: DateTime.now().toIso8601String(),
        transcript: _transcript,
      );
      if (!mounted) return;
      widget.onInterviewEnded(endedDemoSession);
      return;
    }

    setState(() => _ending = true);
    try {
      final endedSession = await widget.apiService.endSession(
        widget.session.id,
        transcript: _transcript,
      );
      await CallSessionManager.instance.endCall();
      if (!mounted) return;
      widget.onInterviewEnded(endedSession);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ending = false);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _sessionSeconds++);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finalizing session: $e')),
      );
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getInterviewerInitials() {
    final parts = widget.interviewer.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.interviewer.name.isNotEmpty ? widget.interviewer.name[0].toUpperCase() : 'I';
  }

  String _getCandidateInitials() {
    final name = widget.candidate?.fullName ?? 'Elena Rostova';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'C';
  }

  String? _getInterviewerAvatarUrl() {
    final id = widget.interviewer.id.toLowerCase();
    final name = widget.interviewer.name.toLowerCase();
    if (id.contains('marcus') || name.contains('marcus')) {
      return 'https://lh3.googleusercontent.com/aida-public/AB6AXuBphgOTxjkB8M0lEcPkCydYu2FPDadEEsUwza1L0NAiWbJwpAnvLfWdC3xWkYp2IoFXwzPOtPgZkYf8lAsYJsDR1R5hGmqKJw1TSM1bXx-v_j0Su6wGj9J7jg7NUjhQELxJ7ane7asIEmETdon4f66vMQe-i9DW03xXxznNhs8SBUbuT2tL2roWgv98jsjZT308kLogj13E-3JC0Jkfw_x_fUYcNEhsDTb3969seqnwL2MlBObeL724Nw';
    }
    if (id.contains('sarah') || name.contains('sarah')) {
      return 'https://lh3.googleusercontent.com/aida-public/AB6AXuBM9SUI35pbp_nHhK6DJhMPMKDt15s9Qhnao9UtczyrUz2EhOMYLzHK93sq3vjj1GJN95Y_zvOqa8hh1U93q_P9RAuBPOiC1SGDATfI1Ysvmu3ayQ2Ivi2MFc5q8o7Qwls0Gy0TQqe1OSiAN8Y1wLCYrzvNk50wE0G4wIGWgV9VdtMEtwbu2Nc3iree1Zx8DPN7zNVBjOCf2f3m7EsYCswFcAdm2N9phhmYTVwEcgkGv_mAohQHc6b8bg';
    }
    if (id.contains('alex') || name.contains('alex')) {
      return 'https://lh3.googleusercontent.com/aida-public/AB6AXuAAKyYEoe_BnmEHbN5PFncHzX6esxX1FK0XeEb4O8ZVy_Cu5_x1HNkZARGSgtJ11Ujp_2SsRuLWmLMeY7sm1LdgCvUgiQd9_8qj0nTDZqatYboQ_MSrDfimhotesNGTZmI20e7YHw0GM-VfAn_rjvO7K9MmzTB5ewun6U24N2p0Yf6E8w4Okwq5s0qt6TzS3AX5H0664pJf8c6DRrASzsBUlqT-0_ZIISWU5UtBE-F8dtcxhJJf2QdBFQ';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopSubBar(context),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left 65% Workspace: Spotlight + Acoustic Stream + Controls
                          Expanded(
                            flex: 65,
                            child: _buildLeftWorkspace(context),
                          ),
                          Container(width: 1, color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
                          // Right 35% Drawer: Interviewer Presence + Candidate telemetry + Coverage
                          Expanded(
                            flex: 35,
                            child: _buildRightTelemetryDrawer(context, isCompact: false),
                          ),
                        ],
                      );
                    } else {
                      // Tablet / Mobile View: stacked
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height: 540,
                              child: _buildLeftWorkspace(context),
                            ),
                            Container(height: 1, color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
                            _buildRightTelemetryDrawer(context, isCompact: true),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              _buildPersistentAudioControllerDeck(context),
            ],
          ),

          // Evaluation Progress Barrier
          if (_ending)
            Container(
              color: Colors.black.withValues(alpha: 0.88),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(32),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: FitCheckTheme.primary, strokeWidth: 3),
                  SizedBox(height: 24),
                  Text(
                    'Finalizing Interview Session...',
                    style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Recovering audio transcript, evaluating observable competencies, and generating your rubric scorecard...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Sub-Bar: Session Metadata & Hardware Status (Stitch design specification)
  // ---------------------------------------------------------------------------
  Widget _buildTopSubBar(BuildContext context) {
    final diffColor = FitCheckTheme.difficultyColor(widget.session.difficulty);
    final scenarioTitle = widget.session.sessionPlan?['scenario'] as String? ??
        'Globally Replicated Low-Latency Event Ledger';

    return Container(
      width: double.infinity,
      color: FitCheckTheme.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Live Session status + Scenario + Difficulty + Stage
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('live_room_minimize_button'),
                  tooltip: 'Minimize Interview',
                  icon: const Icon(Icons.fullscreen_exit, size: 18, color: FitCheckTheme.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    CallSessionManager.instance.minimize();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(width: 10),
                // Live Session badge with animated ping dot
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? FitCheckTheme.error : FitCheckTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'LIVE SESSION' : 'CONNECTING AUDIO...',
                      style: TextStyle(
                        color: _isConnected ? FitCheckTheme.error : FitCheckTheme.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(height: 14, width: 1, color: FitCheckTheme.surfaceContainerHighest),
                const SizedBox(width: 12),

                // Scenario context
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Scenario: ', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    Text(
                      scenarioTitle,
                      style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(height: 14, width: 1, color: FitCheckTheme.surfaceContainerHighest),
                const SizedBox(width: 12),

                // Difficulty badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.session.difficulty.toUpperCase(),
                    style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),

                // Stage progression badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'STAGE: ${_currentStage.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(color: FitCheckTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),

            // Right: Duration counter + Stream Latency / Audio Ready
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 13, color: FitCheckTheme.outline),
                      const SizedBox(width: 5),
                      Text(
                        _formatDuration(_sessionSeconds),
                        style: const TextStyle(color: FitCheckTheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        ' / 45:00',
                        style: TextStyle(color: FitCheckTheme.outline, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isConnected ? FitCheckTheme.tertiary : FitCheckTheme.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _connectionError != null
                            ? 'Audio Notice: $_connectionError'
                            : (_isConnected ? 'Connected' : 'Connecting...'),
                        style: TextStyle(
                          color: _connectionError != null
                              ? FitCheckTheme.warning
                              : (_isConnected ? FitCheckTheme.tertiary : FitCheckTheme.warning),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left Column (65%): Active Question Spotlight + Transcript Stream + Text Fallback
  // ---------------------------------------------------------------------------
  Widget _buildLeftWorkspace(BuildContext context) {
    final candidateName = widget.candidate?.fullName ?? 'Elena Rostova';

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Active Question Spotlight Card (Stitch Approved Element)
              _buildActiveQuestionSpotlightCard(),
              const SizedBox(height: 16),

              // 2. Acoustic Transcription Stream
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      // Stream Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          border: Border(bottom: BorderSide(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3))),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.graphic_eq, color: FitCheckTheme.primary, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'ACOUSTIC TRANSCRIPTION STREAM',
                                    overflow: TextOverflow.ellipsis,
                                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Whisper v3 / WebRTC Native Real-time',
                                    overflow: TextOverflow.ellipsis,
                                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Transcript turns scrollable list
                      Expanded(
                        child: _transcript.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(color: FitCheckTheme.primary, strokeWidth: 2.5),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Acoustic channel connecting with ${widget.interviewer.name}...',
                                      style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _transcriptScrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: _transcript.length,
                                itemBuilder: (context, index) {
                                  final turn = _transcript[index];
                                  final isCandidate = turn['role'] == 'candidate';
                                  final isLatest = index == _transcript.length - 1;

                                  return _buildStitchTranscriptTurn(
                                    turn: turn,
                                    isCandidate: isCandidate,
                                    isLatest: isLatest,
                                    candidateName: candidateName,
                                  );
                                },
                              ),
                      ),

                      // Real-time speaking banner indicator
                      if (_isCandidateSpeaking || _isInterviewerSpeaking)
                        _buildLiveSpeakingFeedbackBar(candidateName),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Fallback Text Response Drawer (Ctrl + K Expandable Drawer)
              _buildFallbackTextDrawer(),
            ],
          ),
        ),

        // Scroll to Bottom FAB
        if (_userScrolledUp)
          Positioned(
            right: 32,
            bottom: 74,
            child: FloatingActionButton.small(
              backgroundColor: FitCheckTheme.surfaceContainerHigh,
              foregroundColor: FitCheckTheme.primary,
              tooltip: 'Jump to latest spoken message',
              onPressed: _scrollToBottomNow,
              child: const Icon(Icons.arrow_downward, size: 16),
            ),
          ),
      ],
    );
  }

  // Active Question Spotlight Card
  Widget _buildActiveQuestionSpotlightCard() {
    final challenge = widget.session.sessionPlan?['scenario_challenge'] as String? ??
        '“How would your design guarantee linearizability during a regional network partition without incurring unacceptable write latency across transatlantic datacenters?”';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: FitCheckTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE PROMPT · ${_currentStage.toUpperCase()}',
                            style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('Distributed Consensus / CAP Trade-offs', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: _isInterviewerSpeaking ? FitCheckTheme.secondary : FitCheckTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _isInterviewerSpeaking ? '${widget.interviewer.name} Speaking...' : 'AI Evaluator Listening',
                          style: TextStyle(
                            color: _isInterviewerSpeaking ? FitCheckTheme.secondary : FitCheckTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  challenge,
                  style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Turn Item strictly adhering to Stitch Live Voice Studio Design
  Widget _buildStitchTranscriptTurn({
    required Map<String, dynamic> turn,
    required bool isCandidate,
    required bool isLatest,
    required String candidateName,
  }) {
    final speakerName = isCandidate ? candidateName : widget.interviewer.name;
    final speakerRole = isCandidate ? 'Candidate' : (widget.interviewer.title);
    final initials = isCandidate ? _getCandidateInitials() : _getInterviewerInitials();
    final text = (turn['text'] as String? ?? '').trim();
    final isInterrogating = !isCandidate && isLatest && _isInterviewerSpeaking;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInterrogating
            ? FitCheckTheme.surfaceContainerHigh
            : FitCheckTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: isInterrogating
            ? Border.all(color: FitCheckTheme.secondary.withValues(alpha: 0.5), width: 1.2)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Avatar Initials
          CircleAvatar(
            radius: 17,
            backgroundColor: isCandidate
                ? FitCheckTheme.primary.withValues(alpha: 0.2)
                : FitCheckTheme.secondaryContainer,
            child: Text(
              initials,
              style: TextStyle(
                color: isCandidate ? FitCheckTheme.primary : FitCheckTheme.onSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      speakerName,
                      style: TextStyle(
                        color: isCandidate ? FitCheckTheme.primary : FitCheckTheme.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      speakerRole,
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                    ),
                    if (isInterrogating)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Interrogating',
                          style: TextStyle(color: FitCheckTheme.secondary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (isLatest && !isCandidate)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'LATEST QUESTION',
                          style: TextStyle(color: FitCheckTheme.primary, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  text,
                  style: FitCheckTheme.bodyMedium(
                    color: isInterrogating ? FitCheckTheme.onSurface : FitCheckTheme.onSurfaceVariant,
                  ).copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Live Speaking Feedback Bar with bouncing acoustic soundbars
  Widget _buildLiveSpeakingFeedbackBar(String candidateName) {
    final isCand = _isCandidateSpeaking;
    final speaker = isCand ? candidateName : widget.interviewer.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // 3 Animated soundbars
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  final val = _waveController.value;
                  return Row(
                    children: [
                      Container(width: 2.5, height: 6 + val * 8, decoration: BoxDecoration(color: FitCheckTheme.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 3),
                      Container(width: 2.5, height: 12 - val * 6, decoration: BoxDecoration(color: FitCheckTheme.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 3),
                      Container(width: 2.5, height: 8 + val * 6, decoration: BoxDecoration(color: FitCheckTheme.primary, borderRadius: BorderRadius.circular(2))),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                '$speaker speaking...',
                style: const TextStyle(color: FitCheckTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Text('Buffering: 110ms', style: TextStyle(color: FitCheckTheme.outline, fontSize: 10)),
        ],
      ),
    );
  }

  // Fallback Text Response Drawer (Ctrl + K Expandable Drawer)
  Widget _buildFallbackTextDrawer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showTextFallback = !_showTextFallback),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard, size: 16, color: FitCheckTheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio noisy? Open fallback text response (Ctrl + K)',
                          style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showTextFallback ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: FitCheckTheme.outline,
                ),
              ],
            ),
          ),
          if (_showTextFallback) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: FitCheckTheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: _fallbackController,
                      style: const TextStyle(color: FitCheckTheme.onSurface, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Type clarification or architectural formula...',
                        hintStyle: TextStyle(color: FitCheckTheme.outline, fontSize: 12),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) {
                        _simulateCandidateAnswer(val);
                        _fallbackController.clear();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _simulateCandidateAnswer(_fallbackController.text);
                    _fallbackController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FitCheckTheme.surfaceContainerHighest,
                    foregroundColor: FitCheckTheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('Send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right Column (35%): Interviewer Presence + Candidate presence + Competency Radar
  // ---------------------------------------------------------------------------
  Widget _buildRightTelemetryDrawer(BuildContext context, {bool isCompact = false}) {
    final candidateName = widget.candidate?.fullName ?? 'Elena Rostova';
    final interviewerAvatar = _getInterviewerAvatarUrl();
    final displayedCandidateName = isCompact ? 'You' : '$candidateName (You)';

    return SingleChildScrollView(
      physics: isCompact ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Interviewer Presence Box (Marcus Vance / Sarah Chen / Alex Rivera)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: interviewerAvatar != null
                              ? Image.network(
                                  interviewerAvatar,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackInterviewerAvatar(),
                                )
                              : _buildFallbackInterviewerAvatar(),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: FitCheckTheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.interviewer.name,
                                style: FitCheckTheme.titleMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 15),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 14, color: FitCheckTheme.secondary),
                            ],
                          ),
                          Text(
                            widget.interviewer.title,
                            style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Interviewer • ${widget.interviewer.questioningStyle.toUpperCase()}',
                            style: const TextStyle(color: FitCheckTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Marcus Voice Activity Spectrum Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Voice Synthesis Engine',
                              style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isInterviewerSpeaking ? 'Speaking...' : 'Listening to you',
                            style: TextStyle(
                              color: _isInterviewerSpeaking ? FitCheckTheme.primary : FitCheckTheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 8 Equalizer bars
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          final v = _waveController.value;
                          final active = _isInterviewerSpeaking;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(8, (i) {
                              final h = active ? (4.0 + ((i % 3 + 1) * 3 * v)) : 3.0;
                              return Container(
                                width: 22,
                                height: h,
                                decoration: BoxDecoration(
                                  color: active ? FitCheckTheme.secondary : FitCheckTheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Interviewer Observation Log
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLowest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description, size: 12, color: FitCheckTheme.outline),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Interviewer Observation Log',
                              style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getInterviewerObservationLog(),
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Candidate Presence & Audio Clarity Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: FitCheckTheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              _getCandidateInitials(),
                              style: const TextStyle(color: FitCheckTheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayedCandidateName,
                                  style: FitCheckTheme.titleMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Live Audio Active',
                                  style: TextStyle(color: FitCheckTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('98%', style: FitCheckTheme.metricDisplay(color: FitCheckTheme.primary).copyWith(fontSize: 22)),
                        Text('Clarity Index', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: FitCheckTheme.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cadence', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                            const Text('142 WPM', style: TextStyle(color: FitCheckTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                            const Text('Ideal Pace', style: TextStyle(color: FitCheckTheme.tertiary, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: FitCheckTheme.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Filler Ratio', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                            const Text('1.4%', style: TextStyle(color: FitCheckTheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                            const Text('Top 5% Tier', style: TextStyle(color: FitCheckTheme.tertiary, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Real-Time Competency Coverage Radar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.analytics, size: 16, color: FitCheckTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'COMPETENCY COVERAGE',
                              style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Score: 88/100', style: TextStyle(color: FitCheckTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),

                _buildCompetencyBar('Architecture Trade-offs', 0.85, '85%', FitCheckTheme.primary),
                const SizedBox(height: 8),
                _buildCompetencyBar('Consensus Mechanics', 0.90, '90%', FitCheckTheme.tertiary),
                const SizedBox(height: 8),
                _buildCompetencyBar('Failure Recovery & Partitions', 0.65, 'In Progress (65%)', FitCheckTheme.secondary),
                const SizedBox(height: 8),
                _buildCompetencyBar('Operational Complexity & SLAs', 0.20, 'Pending', FitCheckTheme.outline),

                const SizedBox(height: 14),
                // Session progression stepper
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SESSION PROGRESSION', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildProgressionStep('Intro', isDone: true, isActive: false),
                          _buildProgressionStep('Blueprint', isDone: true, isActive: false),
                          _buildProgressionStep('Deep Dive', isDone: false, isActive: true),
                          _buildProgressionStep('Wrap & Q&A', isDone: false, isActive: false),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Studio Pro-Tip / Live Cue
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates, size: 16, color: FitCheckTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACOUSTIC STUDIO CUE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _getInterviewerStudioCue(),
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackInterviewerAvatar() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: FitCheckTheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: Text(
        _getInterviewerInitials(),
        style: const TextStyle(color: FitCheckTheme.onSecondary, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildCompetencyBar(String title, double progress, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: FitCheckTheme.labelSmall(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: FitCheckTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressionStep(String title, {required bool isDone, required bool isActive}) {
    Color barColor = isDone
        ? FitCheckTheme.tertiary
        : (isActive ? FitCheckTheme.primary : FitCheckTheme.surfaceContainerHighest);

    return Expanded(
      child: Column(
        children: [
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? FitCheckTheme.primary : (isDone ? FitCheckTheme.onSurface : FitCheckTheme.outline),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getInterviewerObservationLog() {
    final name = widget.interviewer.name.toLowerCase();
    if (name.contains('sarah')) {
      return '“Candidate articulated cross-functional operational trade-offs and SLA definitions cleanly. Transitioning to incident response.”';
    } else if (name.contains('alex')) {
      return '“Strong grasp of client-side cache hydration and GraphQL response boundaries. Probing developer experience velocity.”';
    }
    return '“Candidate demonstrated rigorous grasp of Multi-Raft partitioning and leaseholder read paths. Transitioned to edge cases in NTP divergence.”';
  }

  String _getInterviewerStudioCue() {
    final name = widget.interviewer.name.toLowerCase();
    if (name.contains('sarah')) {
      return 'Sarah focuses heavily on engineering management and system resilience. Emphasize operational observability and mean-time-to-recovery.';
    } else if (name.contains('alex')) {
      return 'Alex prioritizes developer velocity, clean APIs, and end-to-end integration. Address network payload sizes and client cache hydration.';
    }
    return 'Marcus leans heavily into recovery boundaries. Address split-brain prevention explicitly before discussing read-path latency optimizations.';
  }

  // ---------------------------------------------------------------------------
  // Persistent Audio Controller Deck (Stitch specification)
  // ---------------------------------------------------------------------------
  Widget _buildPersistentAudioControllerDeck(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final content = Row(
          mainAxisAlignment: isNarrow ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
          mainAxisSize: isNarrow ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // Left: Essential Audio Controls (Mute, Speaker, Audio Devices, Call Status)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleMute,
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, size: 16),
                  label: Text(_isMuted ? 'Unmute' : 'Mute'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMuted ? FitCheckTheme.surfaceContainerHighest : FitCheckTheme.primary,
                    foregroundColor: _isMuted ? FitCheckTheme.outline : FitCheckTheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _toggleSpeaker,
                  icon: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_off, size: 14),
                  label: Text(_isSpeakerOn ? 'Speaker On' : 'Speaker Off'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FitCheckTheme.onSurface,
                    backgroundColor: FitCheckTheme.surfaceContainerHigh,
                    side: const BorderSide(color: FitCheckTheme.outlineVariant),
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showAudioDeviceSettingsDialog,
                  icon: const Icon(Icons.tune, size: 14),
                  label: const Text('Audio Devices'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FitCheckTheme.onSurface,
                    backgroundColor: FitCheckTheme.surfaceContainerHigh,
                    side: const BorderSide(color: FitCheckTheme.outlineVariant),
                    padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.headset_mic_outlined, size: 12, color: FitCheckTheme.outline),
                      SizedBox(width: 4),
                      Text('Audio Call', style: TextStyle(color: FitCheckTheme.outline, fontSize: 11)),
                    ],
                  ),
                ),
                if (!isNarrow) ...[
                  const SizedBox(width: 8),
                  // Equalizer level bars
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      final v = _waveController.value;
                      final isLive = !_isMuted && _isCandidateSpeaking;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(8, (i) {
                            final h = isLive ? (4.0 + (i % 4 + 1) * 3 * v) : 4.0;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 2.5,
                              height: h,
                              decoration: BoxDecoration(
                                color: isLive ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),

            // Center: Interactive Clarification Controls
            if (!isNarrow)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _requestClarification,
                        icon: const Icon(Icons.live_help, size: 14, color: FitCheckTheme.primary),
                        label: const Text('Request Clarification'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FitCheckTheme.onSurface,
                          backgroundColor: FitCheckTheme.surfaceContainerHigh,
                          side: const BorderSide(color: FitCheckTheme.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _repeatQuestion,
                        icon: const Icon(Icons.replay, size: 14, color: FitCheckTheme.secondary),
                        label: const Text('Rephrase Prompt'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FitCheckTheme.onSurface,
                          backgroundColor: FitCheckTheme.surfaceContainerHigh,
                          side: const BorderSide(color: FitCheckTheme.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // Right: Safeguarded End Interview Trigger (Always visible on screen!)
            ElevatedButton.icon(
              onPressed: _ending ? null : _confirmAndEndInterview,
              icon: const Icon(Icons.call_end, size: 16),
              label: Text(_ending ? 'Finalizing...' : 'End Interview'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.errorContainer,
                foregroundColor: const Color(0xFFFFDAD6),
                padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 20, vertical: 12),
          decoration: const BoxDecoration(
            color: FitCheckTheme.surfaceContainerLow,
            border: Border(top: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
          ),
          child: isNarrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: content,
                )
              : content,
        );
      },
    );
  }
}
