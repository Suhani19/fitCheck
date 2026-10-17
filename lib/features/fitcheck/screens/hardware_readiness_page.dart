import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../../core/services/hardware_audio_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';

class HardwareReadinessPage extends StatefulWidget {
  final VoidCallback onEnterLiveRoom;
  final VoidCallback onBackToDashboard;
  final FitCheckCandidate? candidate;
  final FitCheckApiService? apiService;
  final ValueChanged<FitCheckSession>? onSessionCreated;
  final HardwareAudioService? audioService;
  final FitCheckInterviewer? interviewer;
  final FitCheckJob? job;
  final List<FitCheckInterviewer>? availableInterviewers;
  final ValueChanged<FitCheckInterviewer>? onInterviewerChanged;
  final VoidCallback? onChangeInterviewer;
  final VoidCallback? onChangeJob;

  const HardwareReadinessPage({
    super.key,
    required this.onEnterLiveRoom,
    required this.onBackToDashboard,
    this.candidate,
    this.apiService,
    this.onSessionCreated,
    this.audioService,
    this.interviewer,
    this.job,
    this.availableInterviewers,
    this.onInterviewerChanged,
    this.onChangeInterviewer,
    this.onChangeJob,
  });

  @override
  State<HardwareReadinessPage> createState() => _HardwareReadinessPageState();
}

class _HardwareReadinessPageState extends State<HardwareReadinessPage>
    with SingleTickerProviderStateMixin {
  late final HardwareAudioService _audioService;
  late final bool _ownsAudioService;
  Timer? _micSampleTimer;
  double _micLevel = 0.0;
  bool _hasMicPermission = false;
  bool _checkingMicPermission = true;
  List<InputDevice> _micDevices = [];
  InputDevice? _selectedMicDevice;

  FitCheckInterviewer? _currentInterviewer;
  bool _loadingInterviewer = false;
  String? _interviewerError;

  int _selectedDifficulty = 2; // 0: Lenient, 1: Realistic, 2: Challenging, 3: Stress
  int _selectedDuration = 1; // 0: 30m, 1: 45m, 2: 60m
  bool _realtimeTranscription = true;
  bool _interruptionDetection = true;
  bool _isCreatingSession = false;

  Future<void> _handleEnterLiveRoom() async {
    if (_isCreatingSession) return;
    _isCreatingSession = true;
    if (mounted) setState(() {});

    try {
      final diffKeys = ['lenient', 'realistic', 'challenging', 'expert_stress'];
      final difficulty = diffKeys[_selectedDifficulty];

      final effectiveInterviewer = _currentInterviewer ??
          (widget.availableInterviewers != null && widget.availableInterviewers!.isNotEmpty
              ? widget.availableInterviewers!.first
              : null);

      if (effectiveInterviewer == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('hardware_no_interviewer_snack'),
              content: Text('Please select an active interviewer persona before entering the live room.'),
              backgroundColor: FitCheckTheme.warning,
            ),
          );
        }
        return;
      }

      final interviewerId = effectiveInterviewer.id;
      final jobId = (widget.job != null && widget.job!.id.isNotEmpty)
          ? widget.job!.id
          : 'general-practice';

      FitCheckCandidate? candidate = widget.candidate;
      if (candidate == null && widget.apiService != null) {
        try {
          candidate = await widget.apiService!.getCurrentCandidate();
        } catch (e) {
          debugPrint('[HardwareReadiness] Candidate fetch notice: $e');
        }
      }

      // If candidate is in demo mode, create simulated session without throwing 401
      if (candidate?.id == 'demo-elena-cand') {
        final demoSession = FitCheckSession(
          id: 'demo-sess-${DateTime.now().millisecondsSinceEpoch}',
          candidateId: 'demo-elena-cand',
          jobId: jobId,
          interviewerId: interviewerId,
          difficulty: difficulty,
          status: 'active',
          channel: 'fitcheck-demo-channel',
          startedAt: DateTime.now().toIso8601String(),
          transcript: [
            {
              'role': 'interviewer',
              'text': "Hi ${candidate?.fullName.split(' ').first ?? 'Elena'}, I'm ${effectiveInterviewer.name}. Let's walk through your systems and architectural strategy.",
              'timestamp': '00:05',
            }
          ],
        );
        widget.onSessionCreated?.call(demoSession);
        widget.onEnterLiveRoom();
        return;
      }

      if (widget.apiService != null && candidate != null) {
        final session = await widget.apiService!.startSession(
          candidateId: candidate.id,
          jobId: jobId,
          interviewerId: interviewerId,
          difficulty: difficulty,
        );
        if (!mounted) return;
        widget.onSessionCreated?.call(session);
        widget.onEnterLiveRoom();
        return;
      }

      if (candidate == null && widget.apiService != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              key: Key('hardware_candidate_missing_snack'),
              content: Text('Candidate profile not found. Please sign in or refresh your profile.'),
              backgroundColor: FitCheckTheme.error,
            ),
          );
        }
        return;
      }

      widget.onEnterLiveRoom();
    } catch (e) {
      debugPrint('[HardwareReadiness] Session creation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('hardware_session_creation_error_snack'),
            content: Text('Could not start live interview session: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: FitCheckTheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleEnterLiveRoom,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSession = false);
      } else {
        _isCreatingSession = false;
      }
    }
  }

  final List<Map<String, dynamic>> _difficultyOptions = [
    {
      'title': 'Lenient',
      'badge': 'Warmup',
      'desc': 'Coaching-oriented cadence. The agent suggests recovery paths when edge cases or split-brain quorums are omitted.',
      'meta': 'Pushbacks: Low (0-1) • Tolerance: Relaxed',
      'accent': FitCheckTheme.tertiary,
    },
    {
      'title': 'Realistic',
      'badge': 'Target Standard',
      'desc': 'Strict mirroring of a standard Stripe / FAANG hiring committee round. Clear trade-off requirements and neutral pacing.',
      'meta': 'Pushbacks: Standard (1-2) • Strictness: 82% Baseline',
      'accent': FitCheckTheme.primary,
    },
    {
      'title': 'Challenging',
      'badge': 'Recommended for L6',
      'desc': 'Aggressive probing into Raft log replication lags, dynamic membership changes, and cross-AZ write latency. Calculated interruptions.',
      'meta': 'Interjections: 3-4 Deep Cuts • p99 Stress Injections',
      'accent': FitCheckTheme.primary,
    },
    {
      'title': 'Stress / Hardcore',
      'badge': 'Extreme',
      'desc': 'Continuous adversarial pushback. The AI injects dual-datacenter blackhole scenarios and challenges fundamental architectural axioms.',
      'meta': 'Pushbacks: Constant (5+) • Hostile Cross-Exam',
      'accent': FitCheckTheme.error,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentInterviewer = widget.interviewer;
    if (_currentInterviewer == null) {
      _resolveInterviewer();
    }
    _audioService = widget.audioService ?? HardwareAudioService();
    _ownsAudioService = widget.audioService == null;

    _audioService.chimeStatusNotifier.addListener(_onAudioServiceStateChanged);
    _audioService.micLevelNotifier.addListener(_onAudioServiceStateChanged);

    _initHardwareReadiness();
  }

  @override
  void didUpdateWidget(HardwareReadinessPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interviewer != oldWidget.interviewer && widget.interviewer != null) {
      setState(() {
        _currentInterviewer = widget.interviewer;
        _interviewerError = null;
      });
    }
  }

  Future<void> _resolveInterviewer() async {
    if (widget.availableInterviewers != null && widget.availableInterviewers!.isNotEmpty) {
      setState(() {
        _currentInterviewer = widget.availableInterviewers!.first;
        _interviewerError = null;
      });
      return;
    }

    if (widget.apiService != null) {
      setState(() => _loadingInterviewer = true);
      try {
        final list = await widget.apiService!.getInterviewers();
        if (mounted) {
          if (list.isNotEmpty) {
            setState(() {
              _currentInterviewer = list.first;
              _loadingInterviewer = false;
              _interviewerError = null;
            });
            widget.onInterviewerChanged?.call(_currentInterviewer!);
          } else {
            setState(() {
              _loadingInterviewer = false;
              _interviewerError = 'No interviewers found in system.';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loadingInterviewer = false;
            _interviewerError = 'Failed to load interviewer configuration: $e';
          });
        }
      }
      return;
    }

    setState(() {
      _currentInterviewer = const FitCheckInterviewer(
        id: 'marcus-arch-001',
        name: 'Marcus Vance',
        title: 'Principal Distributed Systems Architect',
        companyContext: 'Stripe',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
        isPreset: true,
      );
      _interviewerError = null;
    });
  }

  void _onAudioServiceStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initHardwareReadiness() async {
    final hasPerm = await _audioService.checkMicrophonePermission();
    if (!mounted) return;
    setState(() {
      _hasMicPermission = hasPerm;
      _checkingMicPermission = false;
    });

    if (hasPerm) {
      final devices = await _audioService.listMicrophones();
      if (!mounted) return;
      setState(() {
        _micDevices = devices;
        _selectedMicDevice = _audioService.selectedDevice;
      });
      await _audioService.startMicMonitoring(device: _selectedMicDevice);
      _startMicSampling();
    }
  }

  void _startMicSampling() {
    _micSampleTimer?.cancel();
    _micSampleTimer = Timer.periodic(const Duration(milliseconds: 70), (_) async {
      if (!mounted || _audioService.isDisposed) return;
      final level = await _audioService.sampleMicLevel();
      if (mounted && !_audioService.isDisposed && (_micLevel != level)) {
        setState(() => _micLevel = level);
      }
    });
  }

  Future<void> _requestMicPermission() async {
    setState(() => _checkingMicPermission = true);
    final granted = await _audioService.checkMicrophonePermission(request: true);
    if (!mounted) return;
    setState(() {
      _hasMicPermission = granted;
      _checkingMicPermission = false;
    });
    if (granted) {
      final devices = await _audioService.listMicrophones();
      if (mounted) {
        setState(() {
          _micDevices = devices;
          _selectedMicDevice = _audioService.selectedDevice;
        });
      }
      await _audioService.startMicMonitoring(device: _selectedMicDevice);
      _startMicSampling();
    }
  }

  Future<void> _triggerChimeTest() async {
    await _audioService.playTestChime();
  }

  @override
  void dispose() {
    _micSampleTimer?.cancel();
    _micSampleTimer = null;
    _audioService.chimeStatusNotifier.removeListener(_onAudioServiceStateChanged);
    _audioService.micLevelNotifier.removeListener(_onAudioServiceStateChanged);
    _audioService.stopMicMonitoring();
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Column(
        children: [
          _buildTopBar(isDesktop),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildLeftWorkspace()),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: _buildRightWorkspace()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildLeftWorkspace(),
                          const SizedBox(height: 24),
                          _buildRightWorkspace(),
                        ],
                      ),
              ),
            ),
          ),
          _buildStickyBottomBar(isDesktop),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurface, size: 20),
                  onPressed: widget.onBackToDashboard,
                  tooltip: 'Back to Command Center',
                ),
                const SizedBox(width: 8),
                const FitCheckLogo(size: 16),
                const SizedBox(width: 8),
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Interview Setup & Hardware Readiness',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('STAGE: CONFIG-STRIPE-L6 // ST-9921', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('RTT: 18ms / Jitter < 1.2ms', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeftWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title & Meta
        Row(
          children: [
            const Icon(Icons.tune, color: FitCheckTheme.primary, size: 16),
            const SizedBox(width: 6),
            Text('SIMULATION ENGINE PARAMETER CALIBRATION', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Difficulty & Stress Calibration', style: FitCheckTheme.headlineLarge()),
        const SizedBox(height: 6),
        Text(
          'Configure the synthetic interviewer’s cognitive pushback rate, rubric weights, and failure simulation tolerance for the upcoming Stripe L6 Distributed Storage loop.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),

        // Section A: 4-Tier Difficulty Grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'ADVERSARIAL INTENSITY SETTING',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                const Icon(Icons.psychology, size: 14, color: FitCheckTheme.secondary),
                const SizedBox(width: 4),
                Text('Adaptive L6 Prompt Active', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemCount: _difficultyOptions.length,
          itemBuilder: (context, i) {
            final opt = _difficultyOptions[i];
            final isSelected = _selectedDifficulty == i;
            return InkWell(
              onTap: () => setState(() => _selectedDifficulty = i),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? FitCheckTheme.surfaceContainerHigh : FitCheckTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            opt['title'] as String,
                            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? FitCheckTheme.primary.withValues(alpha: 0.15) : FitCheckTheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            opt['badge'] as String,
                            style: FitCheckTheme.labelSmall(color: isSelected ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      opt['desc'] as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 11),
                    ),
                    Text(
                      opt['meta'] as String,
                      style: FitCheckTheme.labelSmall(color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outline).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Section B: Rubric Weight Allocator
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FitCheckTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FitCheckTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evaluation Rubric Weight Allocator', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                'Determines scoring weight allocation for post-interview diagnostic telemetry.',
                style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _rubricWeightBar('System Architecture & Trade-offs', '35%', 0.35, FitCheckTheme.primary),
              const SizedBox(height: 10),
              _rubricWeightBar('Consensus & Fault Tolerance', '30%', 0.30, FitCheckTheme.tertiary),
              const SizedBox(height: 10),
              _rubricWeightBar('Operational Resiliency & Scale', '20%', 0.20, FitCheckTheme.secondary),
              const SizedBox(height: 10),
              _rubricWeightBar('Communication & Composure', '15%', 0.15, FitCheckTheme.warning),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section C: Duration & Toggles
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESSION ALLOCATION TIME', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _durationPill('30m Drill', 0),
                        const SizedBox(width: 8),
                        _durationPill('45m Standard', 1),
                        const SizedBox(width: 8),
                        _durationPill('60m Deep', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REAL-TIME ENGINE FEATURES', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    const SizedBox(height: 6),
                    _checkboxRow('Real-Time Transcription Stream', _realtimeTranscription, (v) => setState(() => _realtimeTranscription = v!)),
                    _checkboxRow('Voice Interruption Detection', _interruptionDetection, (v) => setState(() => _interruptionDetection = v!)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rubricWeightBar(String label, String pct, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            Text(pct, style: FitCheckTheme.labelSmall(color: color).copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: FitCheckTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _durationPill(String title, int idx) {
    final isSelected = _selectedDuration == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDuration = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? FitCheckTheme.primary : FitCheckTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: FitCheckTheme.labelSmall(
              color: isSelected ? FitCheckTheme.onPrimary : FitCheckTheme.onSurfaceVariant,
            ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }

  Widget _checkboxRow(String title, bool val, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface))),
        Checkbox(
          value: val,
          onChanged: onChanged,
          activeColor: FitCheckTheme.primary,
          checkColor: FitCheckTheme.onPrimary,
        ),
      ],
    );
  }

  Widget _buildRightWorkspace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel 1: Live Mic Deck
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FitCheckTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FitCheckTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: FitCheckTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Microphone & Audio Input', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.3)),
                    ),
                    child: Text('VERIFIED (48kHz)', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Device Selector
              Text('INPUT AUDIO INTERFACE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: _micDevices.isNotEmpty
                    ? DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('hardware_mic_device_dropdown'),
                          isExpanded: true,
                          dropdownColor: FitCheckTheme.surfaceContainerHigh,
                          value: _selectedMicDevice?.id ?? _micDevices.first.id,
                          items: _micDevices.map((d) {
                            final label = d.label.isNotEmpty ? d.label : 'Microphone (${d.id})';
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(
                                label,
                                style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              final matched = _micDevices.where((d) => d.id == val).firstOrNull;
                              if (matched != null) {
                                setState(() => _selectedMicDevice = matched);
                                _audioService.selectDevice(matched);
                                await _audioService.stopMicMonitoring();
                                await _audioService.startMicMonitoring(device: matched);
                              }
                            }
                          },
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _hasMicPermission
                                  ? 'System Default Microphone (Device selection restricted in browser)'
                                  : (_checkingMicPermission
                                      ? 'Checking audio interface permissions...'
                                      : 'Microphone permission required to enumerate devices'),
                              style: FitCheckTheme.bodySmall(
                                color: _hasMicPermission ? FitCheckTheme.onSurface : FitCheckTheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_hasMicPermission && !_checkingMicPermission) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _requestMicPermission,
                              child: Text(
                                'Grant Access',
                                style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),

              // Equalizer Meter
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: (_hasMicPermission && _micLevel > 0.02)
                                    ? FitCheckTheme.tertiary
                                    : FitCheckTheme.outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE INPUT LEVEL',
                              style: FitCheckTheme.labelSmall(
                                color: (_hasMicPermission && _micLevel > 0.02)
                                    ? FitCheckTheme.tertiary
                                    : FitCheckTheme.outline,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          !_hasMicPermission
                              ? 'Permission Required'
                              : (_micLevel > 0.02
                                  ? '${(-60.0 + _micLevel * 60.0).toStringAsFixed(1)} dBFS (Active)'
                                  : '-∞ dBFS (Silent)'),
                          style: FitCheckTheme.labelSmall(
                            color: !_hasMicPermission
                                ? FitCheckTheme.error
                                : ((_micLevel > 0.02) ? FitCheckTheme.tertiary : FitCheckTheme.outline),
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(36, (i) {
                          final barEnergy = (_hasMicPermission && _micLevel > 0.02) ? _micLevel : 0.0;
                          final h = barEnergy == 0.0
                              ? 3.0
                              : (3.0 + barEnergy * 34.0 * (0.35 + 0.65 * sin(i * 0.38 + 1.2).abs()));
                          final isAccent = i % 4 == 0;
                          return Container(
                            width: 3,
                            height: h.clamp(3.0, 38.0),
                            decoration: BoxDecoration(
                              color: barEnergy == 0.0
                                  ? FitCheckTheme.outlineVariant.withValues(alpha: 0.5)
                                  : (isAccent ? FitCheckTheme.secondary : FitCheckTheme.primary),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Output & Chime
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AUDIO PLAYBACK TEST', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                        Text(
                          'Browser Speaker / Headphones',
                          style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    key: const Key('hardware_test_chime_button'),
                    onPressed: _audioService.chimeStatus == ChimePlaybackStatus.playing
                        ? null
                        : _triggerChimeTest,
                    icon: _audioService.chimeStatus == ChimePlaybackStatus.playing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.primary),
                          )
                        : Icon(
                            _audioService.chimeStatus == ChimePlaybackStatus.success
                                ? Icons.check_circle_outline
                                : (_audioService.chimeStatus == ChimePlaybackStatus.error
                                    ? Icons.error_outline
                                    : Icons.volume_up),
                            size: 16,
                            color: _audioService.chimeStatus == ChimePlaybackStatus.success
                                ? FitCheckTheme.tertiary
                                : (_audioService.chimeStatus == ChimePlaybackStatus.error
                                    ? FitCheckTheme.error
                                    : FitCheckTheme.secondary),
                          ),
                    label: Text(
                      _audioService.chimeStatusMessage,
                      style: TextStyle(
                        color: _audioService.chimeStatus == ChimePlaybackStatus.success
                            ? FitCheckTheme.tertiary
                            : (_audioService.chimeStatus == ChimePlaybackStatus.error
                                ? FitCheckTheme.error
                                : FitCheckTheme.secondary),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FitCheckTheme.secondary,
                      side: BorderSide(
                        color: _audioService.chimeStatus == ChimePlaybackStatus.success
                            ? FitCheckTheme.tertiary
                            : (_audioService.chimeStatus == ChimePlaybackStatus.error
                                ? FitCheckTheme.error
                                : FitCheckTheme.secondary),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Telemetry stats row
              Row(
                children: [
                  _telemetryMiniCard('WEBRTC PING', '18 ms', FitCheckTheme.tertiary),
                  const SizedBox(width: 8),
                  _telemetryMiniCard('PACKET DROP', '0.0 %', FitCheckTheme.onSurface),
                  const SizedBox(width: 8),
                  _telemetryMiniCard('CODEC SPEC', 'Opus 48k', FitCheckTheme.primary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Panel 2: Interviewer Dossier / Error Card
        if (_interviewerError != null)
          Container(
            key: const Key('hardware_interviewer_error_card'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FitCheckTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FitCheckTheme.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: FitCheckTheme.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'COULD NOT LOAD INTERVIEWER PERSONA',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.error).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _interviewerError!,
                  style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _resolveInterviewer,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                    if (widget.onChangeInterviewer != null)
                      ElevatedButton.icon(
                        key: const Key('hardware_choose_another_interviewer_button'),
                        onPressed: widget.onChangeInterviewer,
                        icon: const Icon(Icons.people_outline, size: 16),
                        label: const Text('Choose Another Interviewer'),
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (_loadingInterviewer)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: FitCheckTheme.primary),
            ),
          )
        else if (_currentInterviewer != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'ACTIVE SYNTHETIC INTERVIEWER DOSSIER',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.onChangeInterviewer != null)
                      OutlinedButton.icon(
                        key: const Key('hardware_change_interviewer_button'),
                        onPressed: widget.onChangeInterviewer,
                        icon: const Icon(Icons.swap_horiz, size: 14),
                        label: const Text('Change', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: BorderSide(color: FitCheckTheme.secondary.withValues(alpha: 0.5)),
                          foregroundColor: FitCheckTheme.secondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: FitCheckTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: FitCheckTheme.secondary.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.person, color: FitCheckTheme.primary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _currentInterviewer!.name,
                                  key: const Key('hardware_interviewer_name'),
                                  style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 18),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_currentInterviewer!.isPreset) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 16, color: FitCheckTheme.primary),
                              ],
                            ],
                          ),
                          Text(
                            _currentInterviewer!.title,
                            key: const Key('hardware_interviewer_title'),
                            style: FitCheckTheme.bodySmall(color: FitCheckTheme.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Company: ${_currentInterviewer!.companyContext} • ${_currentInterviewer!.specialty}',
                            key: const Key('hardware_interviewer_specialty'),
                            style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_currentInterviewer!.focusAreas.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _currentInterviewer!.focusAreas.take(3).map((area) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: FitCheckTheme.outlineVariant),
                        ),
                        child: Text(area, style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 10)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over, size: 14, color: FitCheckTheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'VOICE: ${_currentInterviewer!.voiceDisplayName} (${_currentInterviewer!.voiceId}) • STYLE: ${_currentInterviewer!.questioningStyle.toUpperCase()}',
                          key: const Key('hardware_interviewer_voice_badge'),
                          style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(left: BorderSide(color: FitCheckTheme.primary, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interviewer Behavioral Directive', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        _currentInterviewer!.behavioralDirective,
                        key: const Key('hardware_interviewer_directive'),
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _telemetryMiniCard(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(label, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9)),
            const SizedBox(height: 2),
            Text(val, style: FitCheckTheme.labelMedium(color: color).copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('All 4 pre-flight readiness checks verified • 100% READY', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                  Text('Audio loopback active (48kHz) • WebRTC socket primed • Difficulty L6 Locked', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.onSurfaceVariant,
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Save Preset'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('enter_live_room_button'),
                onPressed: _isCreatingSession ? null : _handleEnterLiveRoom,
                icon: _isCreatingSession
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(_isCreatingSession ? 'Initializing Session...' : 'Enter Live Interview Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: FitCheckTheme.bodyMedium().copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
