import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';

class LiveInterviewStudioPage extends StatefulWidget {
  final VoidCallback onConcludeInterview;
  final VoidCallback onBackToDashboard;
  final FitCheckSession? session;
  final FitCheckCandidate? candidate;
  final FitCheckApiService? apiService;
  final ValueChanged<FitCheckEvaluation>? onEvaluationGenerated;

  const LiveInterviewStudioPage({
    super.key,
    required this.onConcludeInterview,
    required this.onBackToDashboard,
    this.session,
    this.candidate,
    this.apiService,
    this.onEvaluationGenerated,
  });

  @override
  State<LiveInterviewStudioPage> createState() => _LiveInterviewStudioPageState();
}

class _LiveInterviewStudioPageState extends State<LiveInterviewStudioPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  Timer? _sessionTimer;
  int _elapsedSeconds = 28 * 60 + 45; // 00:28:45
  bool _isMuted = false;
  bool _showTextFallback = false;
  final TextEditingController _textFallbackController = TextEditingController();
  bool _isConcluding = false;

  Future<void> _handleConcludeInterview() async {
    if (widget.apiService != null && widget.session != null && !_isConcluding) {
      setState(() => _isConcluding = true);
      try {
        final formattedTranscript = _transcriptTurns.map((turn) {
          return {
            'speaker': turn['isInterviewer'] == true ? 'interviewer' : 'candidate',
            'text': turn['text'] as String,
            'timestamp': turn['time'] as String,
          };
        }).toList();

        await widget.apiService!.endSession(
          widget.session!.id,
          transcript: formattedTranscript,
        );

        final evaluation = await widget.apiService!.getEvaluation(widget.session!.id);
        widget.onEvaluationGenerated?.call(evaluation);
      } catch (e) {
        debugPrint('[LiveStudio] Conclude/Evaluation note: $e');
      } finally {
        if (mounted) setState(() => _isConcluding = false);
      }
    }
    widget.onConcludeInterview();
  }

  final List<Map<String, dynamic>> _transcriptTurns = [
    {
      'speaker': 'Marcus Vance',
      'role': 'Principal Architect',
      'avatar': 'MV',
      'isInterviewer': true,
      'isInterrogating': false,
      'time': '26:12',
      'text': 'Walk me through your partition tolerance strategy. What happens when the primary region loses quorum?',
    },
    {
      'speaker': 'Elena Rostova',
      'role': 'Candidate',
      'avatar': 'ER',
      'isInterviewer': false,
      'isInterrogating': false,
      'time': '26:45',
      'text': 'In our configuration, we adopt Multi-Raft groups partitioned by account shard. For cross-region consistency, we enforce lease-based reads with Raft follower-reads backed by hybrid logical clocks (HLC). Write operations route strictly to the active shard leader; upon partition isolation, the leader fails fast via bounded heartbeat timeouts rather than split-braining.',
    },
    {
      'speaker': 'Marcus Vance',
      'role': 'Principal Architect',
      'avatar': 'MV',
      'isInterviewer': true,
      'isInterrogating': true,
      'time': '28:10',
      'text': 'Good, but let’s push on the HLC synchronization bounds. If NTP drifts beyond 250ms, how does your replication state machine prevent stale reads without stalling linearizable transactions?',
    },
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _sessionTimer?.cancel();
    _textFallbackController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _sendFallbackText() {
    final text = _textFallbackController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _transcriptTurns.add({
        'speaker': 'Elena Rostova',
        'role': 'Candidate (Text Clarification)',
        'avatar': 'ER',
        'isInterviewer': false,
        'isInterrogating': false,
        'time': _formatTime(_elapsedSeconds),
        'text': text,
      });
      _textFallbackController.clear();
      _showTextFallback = false;
    });
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
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCenterStage()),
                      Container(width: 360, color: FitCheckTheme.surfaceContainerLow, child: _buildRightDrawer()),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCenterStage(),
                        _buildRightDrawer(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 60,
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
                  tooltip: 'Exit to Dashboard',
                ),
                const SizedBox(width: 8),
                const FitCheckLogo(size: 16),
                const SizedBox(width: 8),
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Flexible(child: Text('Live Voice Studio', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('SESSION: STR-9821-L6', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Real-Time Audio Active', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_formatTime(_elapsedSeconds)} / 45:00',
                  style: FitCheckTheme.labelMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterStage() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Prompt Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(left: BorderSide(color: FitCheckTheme.primary, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: FitCheckTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                                child: Text('ACTIVE PROMPT · Q3', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                              ),
                              const SizedBox(width: 8),
                              Text('Distributed Consensus / CAP Trade-offs', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 14, color: FitCheckTheme.primary),
                              const SizedBox(width: 4),
                              Text('AI Evaluator Listening', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '“How would your design guarantee linearizability during a regional network partition without incurring unacceptable write latency across transatlantic datacenters?”',
                        style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 18, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Live Transcript Box
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.graphic_eq, color: FitCheckTheme.primary, size: 18),
                              const SizedBox(width: 6),
                              Text('ACOUSTIC TRANSCRIPTION STREAM', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text('Whisper v3 Native Real-time', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._transcriptTurns.map((turn) => _buildTranscriptTile(turn)),
                      const SizedBox(height: 12),

                      // Candidate speaking live pulse indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Row(
                                    children: List.generate(4, (i) {
                                      return Container(
                                        width: 2,
                                        height: 10.0 + (i * 2),
                                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                        color: FitCheckTheme.primary,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Elena: ', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      '“To mitigate uncertainty windows, we introduce TrueTime-style wait intervals...”',
                                      style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Buffering: 110ms', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Fallback text toggle
                      InkWell(
                        onTap: () => setState(() => _showTextFallback = !_showTextFallback),
                        child: Row(
                          children: [
                            const Icon(Icons.keyboard, size: 16, color: FitCheckTheme.outline),
                            const SizedBox(width: 6),
                            Text(
                              _showTextFallback ? 'Hide text response' : 'Audio noisy? Open fallback text response (Ctrl + K)',
                              style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                            ),
                          ],
                        ),
                      ),
                      if (_showTextFallback) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textFallbackController,
                                onSubmitted: (_) => _sendFallbackText(),
                                style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Type clarification or architectural formula...',
                                  hintStyle: FitCheckTheme.bodySmall(color: FitCheckTheme.outline),
                                  filled: true,
                                  fillColor: FitCheckTheme.surfaceContainerLowest,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: FitCheckTheme.outlineVariant)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _sendFallbackText,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FitCheckTheme.surfaceContainerHigh,
                                foregroundColor: FitCheckTheme.onSurface,
                              ),
                              child: const Text('Send'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Persistent Audio Controller Deck
        _buildBottomAudioController(),
      ],
    );
  }

  Widget _buildTranscriptTile(Map<String, dynamic> turn) {
    final isInterviewer = turn['isInterviewer'] as bool;
    final isInterrogating = turn['isInterrogating'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInterrogating ? FitCheckTheme.surfaceContainerHigh : FitCheckTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
        border: isInterrogating ? Border.all(color: FitCheckTheme.secondary.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isInterviewer ? FitCheckTheme.secondaryContainer : FitCheckTheme.primary.withValues(alpha: 0.2),
            child: Text(
              turn['avatar'] as String,
              style: FitCheckTheme.labelSmall(color: isInterviewer ? FitCheckTheme.secondary : FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          turn['speaker'] as String,
                          style: FitCheckTheme.bodySmall(color: isInterviewer ? FitCheckTheme.secondary : FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (isInterrogating) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: FitCheckTheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                            child: Text('Interrogating', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary).copyWith(fontSize: 9)),
                          ),
                        ],
                      ],
                    ),
                    Text(turn['time'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  turn['text'] as String,
                  style: FitCheckTheme.bodyMedium(color: isInterrogating ? FitCheckTheme.onSurface : FitCheckTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAudioController() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _isMuted = !_isMuted),
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, size: 16),
                label: Text(_isMuted ? 'Unmute Mic' : 'Mute Mic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMuted ? FitCheckTheme.surfaceContainerHigh : FitCheckTheme.primary,
                  foregroundColor: _isMuted ? FitCheckTheme.onSurface : FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 14),
              // Mic wave visualizer
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(8, (i) {
                    final h = _isMuted ? 4.0 : 4.0 + (sin(i + _waveController.value * pi).abs() * 18);
                    return Container(
                      width: 2.5,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      color: _isMuted ? FitCheckTheme.outline : FitCheckTheme.primary,
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Text('-14.2 dBFS • Opus 48k', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.draw, size: 16),
                label: const Text('Architecture Canvas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.onSurfaceVariant,
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('conclude_interview_button'),
                onPressed: _isConcluding ? null : _handleConcludeInterview,
                icon: _isConcluding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.stop_circle_outlined, size: 16),
                label: Text(_isConcluding
                    ? 'Generating AI Evaluation...'
                    : 'Conclude Simulation & Generate Evaluation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightDrawer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interviewer Persona Header Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.person, color: FitCheckTheme.secondary, size: 24),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marcus Vance', style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Speaking · -16.2 dB', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Pacing & Delivery Telemetry
          Text('REAL-TIME PACING TELEMETRY', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 8),
          _telemetryMetricCard('Speaking Cadence', '142 WPM', 'Optimal zone (130-155 WPM)', FitCheckTheme.tertiary),
          const SizedBox(height: 8),
          _telemetryMetricCard('Filler Word Frequency', '1.2 %', 'Low • Nominal composure', FitCheckTheme.primary),
          const SizedBox(height: 8),
          _telemetryMetricCard('Interruption Recovery', '92 %', 'Seamless re-entry', FitCheckTheme.tertiary),
          const SizedBox(height: 20),

          // Live Rubric Depth Evaluation
          Text('REAL-TIME COMPETENCY RUBRIC', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 10),
          _rubricScoreBar('Distributed Systems Depth', '4.6 / 5.0', 0.92, FitCheckTheme.primary),
          const SizedBox(height: 8),
          _rubricScoreBar('Trade-off Articulation', '4.2 / 5.0', 0.84, FitCheckTheme.tertiary),
          const SizedBox(height: 8),
          _rubricScoreBar('Socratic Pushback Composure', '4.8 / 5.0', 0.96, FitCheckTheme.secondary),
          const SizedBox(height: 8),
          _rubricScoreBar('Edge-Case Resilience', '3.9 / 5.0', 0.78, FitCheckTheme.warning),
          const SizedBox(height: 20),

          // Live Observation Feed
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
              border: const Border(left: BorderSide(color: FitCheckTheme.tertiary, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates, size: 14, color: FitCheckTheme.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Evaluator Telemetry Insight',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Strong Multi-Raft justification. Consider explicitly stating failover heartbeat thresholds before moving to partition recovery.',
                  style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryMetricCard(String title, String val, String sub, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: FitCheckTheme.metricDisplay(color: valColor).copyWith(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _rubricScoreBar(String label, String score, double ratio, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(score, style: FitCheckTheme.labelSmall(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: FitCheckTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
