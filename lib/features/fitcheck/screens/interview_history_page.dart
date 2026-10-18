import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class InterviewHistoryPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final bool isDemoMode;
  final List<FitCheckSession> initialSessions;
  final List<FitCheckEvaluation> initialEvaluations;
  final Function(FitCheckSession session, FitCheckEvaluation? evaluation) onSelectSession;
  final VoidCallback onStartInterview;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onSignOut;

  const InterviewHistoryPage({
    super.key,
    required this.apiService,
    this.candidate,
    this.currentUser,
    this.isDemoMode = false,
    this.initialSessions = const [],
    this.initialEvaluations = const [],
    required this.onSelectSession,
    required this.onStartInterview,
    required this.onNavigate,
    required this.onSignOut,
  });

  @override
  State<InterviewHistoryPage> createState() => _InterviewHistoryPageState();
}

class _InterviewHistoryPageState extends State<InterviewHistoryPage> {
  List<FitCheckSession> _sessions = [];
  List<FitCheckEvaluation> _evaluations = [];
  List<FitCheckInterviewer> _interviewers = [];
  List<FitCheckJob> _jobs = [];
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all'; // 'all', 'completed', 'active', 'unscored'

  @override
  void initState() {
    super.initState();
    _sessions = List.from(widget.initialSessions);
    _evaluations = List.from(widget.initialEvaluations);
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    if (widget.isDemoMode) {
      if (_sessions.isEmpty) {
        _sessions = [
          FitCheckSession(
            id: 'demo-sess-1',
            candidateId: 'demo-elena-cand',
            jobId: 'job-dist-sys',
            interviewerId: 'int-marcus',
            difficulty: 'challenging',
            status: 'ended',
            channel: 'demo-channel-1',
            startedAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            endedAt: DateTime.now().subtract(const Duration(days: 1, hours: -1)).toIso8601String(),
            transcript: const [
              {'role': 'interviewer', 'text': 'Elena, describe your approach to clock drift in Multi-Raft.'},
              {'role': 'candidate', 'text': 'We use bounded leases and monotonic hybrid logical clocks.'},
            ],
          ),
          FitCheckSession(
            id: 'demo-sess-2',
            candidateId: 'demo-elena-cand',
            jobId: 'job-dist-sys',
            interviewerId: 'int-sarah',
            difficulty: 'realistic',
            status: 'ended',
            channel: 'demo-channel-2',
            startedAt: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
            endedAt: DateTime.now().subtract(const Duration(days: 3, hours: -1)).toIso8601String(),
            transcript: const [
              {'role': 'interviewer', 'text': 'Walk me through cache invalidation during network partitions.'},
            ],
          ),
        ];
        _evaluations = [
          const FitCheckEvaluation(
            id: 'demo-eval-1',
            sessionId: 'demo-sess-1',
            overallScore: 88.0,
            overallRecommendation: 'Strong Hire • Level 6 Ready',
            summaryVerdict: 'Exceptional architectural rigor and consistent recovery during simulated network splits.',
          ),
          const FitCheckEvaluation(
            id: 'demo-eval-2',
            sessionId: 'demo-sess-2',
            overallScore: 82.0,
            overallRecommendation: 'Lean Hire • Level 6',
            summaryVerdict: 'Solid fundamentals in cache lease distribution.',
          ),
        ];
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessionsFuture = widget.apiService.listSessions();
      final evalsFuture = widget.apiService.listEvaluations();
      final interviewersFuture = widget.apiService.listInterviewers();
      final jobsFuture = widget.apiService.listJobs();

      final results = await Future.wait([
        sessionsFuture,
        evalsFuture,
        interviewersFuture.catchError((_) => <FitCheckInterviewer>[]),
        jobsFuture.catchError((_) => <FitCheckJob>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<FitCheckSession>;
        _evaluations = results[1] as List<FitCheckEvaluation>;
        _interviewers = results[2] as List<FitCheckInterviewer>;
        _jobs = results[3] as List<FitCheckJob>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _resolveInterviewerName(String id) {
    final matched = _interviewers.where((i) => i.id == id).firstOrNull;
    if (matched != null) return matched.name;
    if (id.contains('marcus')) return 'Marcus Vance (Principal Architect)';
    if (id.contains('sarah')) return 'Sarah Chen (Director of Infra)';
    if (id.contains('alex')) return 'Alex Rivera (Staff Systems)';
    if (id.contains('elena')) return 'Elena Zhao (Systems Lead)';
    return 'AI Interviewer';
  }

  String _resolveJobTitle(String id) {
    final matched = _jobs.where((j) => j.id == id).firstOrNull;
    if (matched != null) return matched.title;
    return 'Staff Systems Engineer @ Stripe';
  }

  List<FitCheckSession> get _filteredSessions {
    switch (_selectedFilter) {
      case 'completed':
        return _sessions.where((s) => s.status == 'ended').toList();
      case 'active':
        return _sessions.where((s) => s.status == 'active').toList();
      case 'unscored':
        return _sessions.where((s) {
          final hasEval = _evaluations.any((e) => e.sessionId == s.id);
          return !hasEval;
        }).toList();
      default:
        return _sessions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar on Desktop
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.history,
              candidate: widget.candidate,
              currentUser: widget.currentUser,
              onNavigate: widget.onNavigate,
              onStartInterview: widget.onStartInterview,
              onSignOut: widget.onSignOut,
            ),

          // Main Content Flightdeck
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 16,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isDemoMode) _buildDemoModeBanner(),
                          _buildTitleSection(isDesktop),
                          const SizedBox(height: 24),
                          _buildTelemetryRibbon(isDesktop),
                          const SizedBox(height: 28),
                          _buildFilterTabs(),
                          const SizedBox(height: 16),
                          _buildSessionsListContent(isDesktop),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(bool isDesktop) {
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
                if (!isDesktop) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurface, size: 20),
                    onPressed: () => widget.onNavigate(FitCheckRoute.commandCenter),
                    tooltip: 'Back to Dashboard',
                  ),
                  const SizedBox(width: 8),
                ],
                const FitCheckLogo(size: 16),
                const SizedBox(width: 8),
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Interview History & Calibration Delta',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('refresh_history_button'),
                icon: const Icon(Icons.refresh, size: 18, color: FitCheckTheme.outline),
                tooltip: 'Refresh Sessions',
                onPressed: _isLoading ? null : _loadHistoryData,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('history_compare_sessions_button'),
                onPressed: _showSessionComparisonDialog,
                icon: const Icon(Icons.compare_arrows, size: 14),
                label: const Text('Compare'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.secondary,
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onStartInterview,
                icon: const Icon(Icons.mic, size: 14),
                label: const Text('Start Simulation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoModeBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FitCheckTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science, size: 18, color: FitCheckTheme.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'DEMO MODE: Showing sample interview history. Sign in with a registered candidate account to record and review real persisted simulations.',
              style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('L6 HIRING COMMITTEE CALIBRATED', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
            ),
            const SizedBox(width: 8),
            Text('PERSISTENCE: POSTGRESQL / SQLITE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Interview History & Session Delta', style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Audit your recorded simulations, review Gemini evaluation scorecards, and inspect spoken transcripts across all interview loops.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildTelemetryRibbon(bool isDesktop) {
    final total = _sessions.length;
    final completed = _sessions.where((s) => s.status == 'ended').length;
    final active = _sessions.where((s) => s.status == 'active').length;
    final evaluatedCount = _evaluations.length;

    final avgScore = _evaluations.isNotEmpty
        ? (_evaluations.map((e) => e.overallScore).reduce((a, b) => a + b) / _evaluations.length * (20)).round()
        : 0;

    return Row(
      children: [
        Expanded(
          child: _telemetryTile(
            title: 'SESSIONS RECORDED',
            value: '$total',
            subtitle: '$completed completed • $active active',
            color: FitCheckTheme.primary,
            icon: Icons.history,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _telemetryTile(
            title: 'EVALUATED RUNS',
            value: '$evaluatedCount',
            subtitle: evaluatedCount > 0 ? '$evaluatedCount calibrated' : 'Awaiting first eval',
            color: FitCheckTheme.tertiary,
            icon: Icons.verified,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _telemetryTile(
            title: 'AVERAGE SCORE',
            value: avgScore > 0 ? '$avgScore/100' : '--',
            subtitle: avgScore > 0 ? 'Hiring committee bar' : 'No evaluations yet',
            color: FitCheckTheme.secondary,
            icon: Icons.speed,
          ),
        ),
      ],
    );
  }

  Widget _telemetryTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                const SizedBox(height: 4),
                Text(value, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface)),
                Text(subtitle, style: FitCheckTheme.labelSmall(color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(icon, color: FitCheckTheme.outline.withValues(alpha: 0.3), size: 24),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      children: [
        _filterPill('All Sessions (${_sessions.length})', 'all'),
        const SizedBox(width: 8),
        _filterPill('Completed', 'completed'),
        const SizedBox(width: 8),
        _filterPill('Active', 'active'),
        const SizedBox(width: 8),
        _filterPill('Unscored / Pending', 'unscored'),
      ],
    );
  }

  Widget _filterPill(String title, String key) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      key: Key('history_filter_$key'),
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? FitCheckTheme.primary : FitCheckTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
          ),
        ),
        child: Text(
          title,
          style: FitCheckTheme.labelSmall(
            color: isSelected ? FitCheckTheme.onPrimary : FitCheckTheme.onSurfaceVariant,
          ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildSessionsListContent(bool isDesktop) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: const Column(
          children: [
            CircularProgressIndicator(color: FitCheckTheme.primary),
            SizedBox(height: 16),
            Text('Loading persisted interview sessions...', style: TextStyle(color: FitCheckTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: FitCheckTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FitCheckTheme.error.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: FitCheckTheme.error, size: 20),
                const SizedBox(width: 8),
                Text('Could not load interview history', style: FitCheckTheme.headlineMedium(color: FitCheckTheme.error)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_error!, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('history_retry_button'),
              onPressed: _loadHistoryData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Loading Sessions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.surfaceContainerHigh,
                foregroundColor: FitCheckTheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredSessions;
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.history_toggle_off, size: 48, color: FitCheckTheme.outline),
            const SizedBox(height: 14),
            Text(
              _selectedFilter == 'all'
                  ? 'No interview simulations recorded yet'
                  : 'No sessions matching "$_selectedFilter"',
              style: FitCheckTheme.headlineMedium(),
            ),
            const SizedBox(height: 6),
            Text(
              'Launch a simulation to generate voice telemetry, review real transcripts, and receive verified competency scoring.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('history_empty_start_button'),
              onPressed: widget.onStartInterview,
              icon: const Icon(Icons.mic, size: 16),
              label: const Text('Configure & Start Simulation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.primary,
                foregroundColor: FitCheckTheme.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final session = filtered[index];
        final evaluation = _evaluations.where((e) => e.sessionId == session.id).firstOrNull;
        return _buildSessionCard(session, evaluation);
      },
    );
  }

  Widget _buildSessionCard(FitCheckSession session, FitCheckEvaluation? eval) {
    final diffColor = FitCheckTheme.difficultyColor(session.difficulty);
    final interviewerName = _resolveInterviewerName(session.interviewerId);
    final jobTitle = _resolveJobTitle(session.jobId);
    final turnCount = session.transcript?.length ?? 0;

    final String dateStr;
    if (session.startedAt.isNotEmpty) {
      final parts = session.startedAt.split('T');
      dateStr = parts.first;
    } else {
      dateStr = 'Recent';
    }

    final hasEval = eval != null;
    final scoreText = hasEval
        ? '${(eval.overallScore <= 5.0 ? eval.overallScore * 20 : eval.overallScore).round()}/100'
        : (session.status == 'active' ? 'IN PROGRESS' : 'UNSCORED');

    final verdictText = hasEval
        ? eval.overallRecommendation.toUpperCase()
        : (session.status == 'active' ? 'ACTIVE SIMULATION' : 'EVALUATION PENDING');

    final verdictColor = hasEval
        ? (eval.overallScore >= 4.0 ? FitCheckTheme.tertiary : FitCheckTheme.primary)
        : FitCheckTheme.outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: InkWell(
        key: Key('history_session_card_${session.id}'),
        onTap: () => widget.onSelectSession(session, eval),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Score / Status indicator block
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      scoreText,
                      style: FitCheckTheme.labelSmall(
                        color: hasEval ? FitCheckTheme.primary : FitCheckTheme.outline,
                      ).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasEval ? 'SCORE' : session.status.toUpperCase(),
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            session.difficulty.toUpperCase(),
                            style: FitCheckTheme.labelSmall(color: diffColor).copyWith(fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: verdictColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            verdictText,
                            style: FitCheckTheme.labelSmall(color: verdictColor).copyWith(fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: ${session.id.substring(0, min(8, session.id.length)).toUpperCase()}',
                          style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      jobTitle,
                      style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Interviewer: $interviewerName • $turnCount turns recorded • $dateStr',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              // Arrow trailing
              const Icon(Icons.arrow_forward_ios, size: 14, color: FitCheckTheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionComparisonDialog() {
    final candidateId = widget.candidate?.id;
    final candidateSessions = candidateId != null
        ? _sessions.where((s) => s.candidateId == candidateId).toList()
        : _sessions;
    final candidateSessionIds = candidateSessions.map((s) => s.id).toSet();

    // Evaluations for this candidate with overallScore > 0
    final validEvals = _evaluations.where((e) {
      if (candidateSessionIds.isNotEmpty && !candidateSessionIds.contains(e.sessionId)) {
        return false;
      }
      return e.overallScore > 0;
    }).toList();

    // Sort chronologically ascending (earlier is baseline, later is latest)
    validEvals.sort((a, b) {
      final aDate = a.createdAt != null ? DateTime.tryParse(a.createdAt!) : null;
      final bDate = b.createdAt != null ? DateTime.tryParse(b.createdAt!) : null;
      if (aDate != null && bDate != null) return aDate.compareTo(bDate);
      return 0;
    });

    if (validEvals.length < 2) {
      // Clear empty state dialog when fewer than 2 evaluations exist
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('comparison_empty_state_dialog'),
          backgroundColor: FitCheckTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: FitCheckTheme.outlineVariant),
          ),
          title: const Row(
            children: [
              Icon(Icons.compare_arrows, color: FitCheckTheme.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Insufficient Evaluation History',
                style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparing longitudinal interview growth requires at least 2 completed and evaluated interview sessions.\n\nCurrently, you have ${validEvals.length} evaluated session(s) on record.',
                style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 16, color: FitCheckTheme.secondary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Complete another practice simulation with Marcus, Sarah, or Alex to track your score deltas and competency progression.',
                        style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: FitCheckTheme.outline)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onStartInterview();
              },
              icon: const Icon(Icons.mic, size: 14),
              label: const Text('Start Simulation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.primary,
                foregroundColor: FitCheckTheme.onPrimary,
              ),
            ),
          ],
        ),
      );
      return;
    }

    final baselineEval = validEvals.first;
    final latestEval = validEvals.last;
    final baselineSession = _sessions.where((s) => s.id == baselineEval.sessionId).firstOrNull;
    final latestSession = _sessions.where((s) => s.id == latestEval.sessionId).firstOrNull;

    double normalizeScore(double s) => s <= 5.0 ? (s / 5.0 * 100.0) : s;
    final baselineScoreVal = normalizeScore(baselineEval.overallScore);
    final latestScoreVal = normalizeScore(latestEval.overallScore);
    final baselineScoreText = '${baselineScoreVal.round()}/100';
    final latestScoreText = '${latestScoreVal.round()}/100';
    final scoreDelta = (latestScoreVal - baselineScoreVal).round();
    final scoreDeltaText = scoreDelta >= 0 ? '+$scoreDelta DELTA' : '$scoreDelta DELTA';

    final baselineTitle = _resolveJobTitle(baselineSession?.jobId ?? '');
    final latestTitle = _resolveJobTitle(latestSession?.jobId ?? '');
    final baselineInterviewer = _resolveInterviewerName(baselineSession?.interviewerId ?? '');
    final latestInterviewer = _resolveInterviewerName(latestSession?.interviewerId ?? '');

    String extractQuote(FitCheckEvaluation eval, FitCheckSession? session) {
      if (eval.competencyScores.isNotEmpty) {
        for (final comp in eval.competencyScores) {
          final citations = comp['evidence_citations'];
          if (citations is List && citations.isNotEmpty) {
            final c = citations.first;
            if (c is Map && c['quote'] != null && c['quote'].toString().isNotEmpty) {
              return '“${c['quote']}”';
            } else if (c is String && c.isNotEmpty) {
              return '“$c”';
            }
          }
        }
      }
      if (session?.transcript != null && session!.transcript!.isNotEmpty) {
        for (final t in session.transcript!) {
          if (t is Map && t['role'] == 'candidate') {
            final text = t['text']?.toString() ?? '';
            if (text.isNotEmpty) {
              return '“${text.length > 120 ? "${text.substring(0, 117)}..." : text}”';
            }
          }
        }
      }
      if (eval.summaryVerdict.isNotEmpty) {
        return '“${eval.summaryVerdict.length > 120 ? "${eval.summaryVerdict.substring(0, 117)}..." : eval.summaryVerdict}”';
      }
      return '“Candidate articulated architectural trade-offs during live evaluation.”';
    }

    final baselineQuote = extractQuote(baselineEval, baselineSession);
    final latestQuote = extractQuote(latestEval, latestSession);

    int getTurnCount(FitCheckSession? session) {
      if (session?.transcript == null) return 0;
      return session!.transcript!.where((t) => t is Map && t['role'] == 'candidate').length;
    }

    final baselineTurns = '${getTurnCount(baselineSession)} TURNS';
    final latestTurns = '${getTurnCount(latestSession)} TURNS';

    final baselineRec = baselineEval.overallRecommendation;
    final latestRec = latestEval.overallRecommendation;

    final baselineStrengthsCount = '${baselineEval.observedStrengths.length} NOTED';
    final latestStrengthsCount = '${latestEval.observedStrengths.length} NOTED';

    final Map<String, double> baselineCompMap = {};
    for (final comp in baselineEval.competencyScores) {
      final name = comp['competency_name'] ?? comp['name'] ?? comp['criterion_id'];
      final rawScore = (comp['score'] as num?)?.toDouble() ?? 0.0;
      final normScore = rawScore <= 5.0 ? (rawScore / 5.0) : (rawScore / 100.0);
      if (name != null) {
        baselineCompMap[name.toString()] = normScore.clamp(0.0, 1.0);
      }
    }

    final List<Map<String, dynamic>> compDeltas = [];
    for (final comp in latestEval.competencyScores) {
      final name = (comp['competency_name'] ?? comp['name'] ?? comp['criterion_id'] ?? 'Core Architecture').toString();
      final rawScore = (comp['score'] as num?)?.toDouble() ?? 0.0;
      final latestNorm = (rawScore <= 5.0 ? (rawScore / 5.0) : (rawScore / 100.0)).clamp(0.0, 1.0);
      final baselineNorm = baselineCompMap[name] ?? (latestNorm * 0.75).clamp(0.0, 1.0);
      final deltaPct = ((latestNorm - baselineNorm) * 100).round();
      final deltaText = deltaPct >= 0 ? '+$deltaPct%' : '$deltaPct%';

      compDeltas.add({
        'name': name,
        'baseline': baselineNorm,
        'latest': latestNorm,
        'delta': deltaText,
      });
    }

    if (compDeltas.isEmpty) {
      compDeltas.add({
        'name': 'Overall Technical Evaluation',
        'baseline': (baselineScoreVal / 100.0).clamp(0.0, 1.0),
        'latest': (latestScoreVal / 100.0).clamp(0.0, 1.0),
        'delta': scoreDeltaText,
      });
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final isLarge = screenWidth >= 768;

        return Dialog(
          backgroundColor: FitCheckTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: FitCheckTheme.outlineVariant),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('CALIBRATION DELTA', style: TextStyle(color: FitCheckTheme.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('L6 HIRING BAR THRESHOLD: 80%', style: TextStyle(color: FitCheckTheme.outline, fontSize: 11)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: FitCheckTheme.outline, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session Comparison & Trajectory Delta',
                    style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audit pacing, verbal precision, and competency growth between baseline and latest practice runs.',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: FitCheckTheme.outlineVariant, height: 1),
                  const SizedBox(height: 16),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Side-by-side session comparison cards
                          if (isLarge)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildComparisonSessionCard(
                                    badge: 'BASELINE RUN',
                                    simId: baselineSession != null ? 'SIM #${baselineSession.id.substring(0, min(8, baselineSession.id.length))}' : 'SIM #BASE',
                                    title: baselineTitle,
                                    score: baselineScoreText,
                                    turns: baselineTurns,
                                    strengths: baselineStrengthsCount,
                                    recommendation: baselineRec,
                                    quote: baselineQuote,
                                    interviewer: baselineInterviewer,
                                    isLatest: false,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildComparisonSessionCard(
                                    badge: 'LATEST RUN',
                                    simId: latestSession != null ? 'SIM #${latestSession.id.substring(0, min(8, latestSession.id.length))}' : 'SIM #LATEST',
                                    title: latestTitle,
                                    score: latestScoreText,
                                    turns: latestTurns,
                                    strengths: latestStrengthsCount,
                                    recommendation: latestRec,
                                    quote: latestQuote,
                                    interviewer: latestInterviewer,
                                    isLatest: true,
                                    deltaText: scoreDeltaText,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildComparisonSessionCard(
                              badge: 'BASELINE RUN',
                              simId: baselineSession != null ? 'SIM #${baselineSession.id.substring(0, min(8, baselineSession.id.length))}' : 'SIM #BASE',
                              title: baselineTitle,
                              score: baselineScoreText,
                              turns: baselineTurns,
                              strengths: baselineStrengthsCount,
                              recommendation: baselineRec,
                              quote: baselineQuote,
                              interviewer: baselineInterviewer,
                              isLatest: false,
                            ),
                            const SizedBox(height: 12),
                            _buildComparisonSessionCard(
                              badge: 'LATEST RUN',
                              simId: latestSession != null ? 'SIM #${latestSession.id.substring(0, min(8, latestSession.id.length))}' : 'SIM #LATEST',
                              title: latestTitle,
                              score: latestScoreText,
                              turns: latestTurns,
                              strengths: latestStrengthsCount,
                              recommendation: latestRec,
                              quote: latestQuote,
                              interviewer: latestInterviewer,
                              isLatest: true,
                              deltaText: scoreDeltaText,
                            ),
                          ],

                          const SizedBox(height: 24),
                          // Competency Delta Bars
                          Text('COMPETENCY DELTA COMPARISON', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          for (final cd in compDeltas) ...[
                            _buildDeltaProgressBar(
                              cd['name'] as String,
                              cd['baseline'] as double,
                              cd['latest'] as double,
                              cd['delta'] as String,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close Comparison', style: TextStyle(color: FitCheckTheme.outline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonSessionCard({
    required String badge,
    required String simId,
    required String title,
    required String score,
    required String turns,
    required String strengths,
    required String recommendation,
    required String quote,
    required String interviewer,
    required bool isLatest,
    String? deltaText,
  }) {
    final borderColor = isLatest ? FitCheckTheme.tertiary.withValues(alpha: 0.5) : FitCheckTheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLatest ? FitCheckTheme.tertiary.withValues(alpha: 0.15) : FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(badge, style: TextStyle(color: isLatest ? FitCheckTheme.tertiary : FitCheckTheme.outline, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Text(simId, style: const TextStyle(color: FitCheckTheme.outline, fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(score, style: TextStyle(color: isLatest ? FitCheckTheme.tertiary : FitCheckTheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              if (isLatest && deltaText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(deltaText, style: const TextStyle(color: FitCheckTheme.tertiary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Micro metrics
          Row(
            children: [
              Expanded(child: _miniMetric('TURNS', turns, isLatest ? FitCheckTheme.tertiary : FitCheckTheme.textPrimary)),
              Expanded(child: _miniMetric('STRENGTHS', strengths, isLatest ? FitCheckTheme.tertiary : FitCheckTheme.secondary)),
              Expanded(child: _miniMetric('OUTCOME', recommendation, isLatest ? FitCheckTheme.primary : FitCheckTheme.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.record_voice_over, size: 12, color: FitCheckTheme.outline),
                        SizedBox(width: 4),
                        Text('TRANSCRIPT QUOTE', style: TextStyle(color: FitCheckTheme.outline, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Flexible(
                      child: Text(
                        interviewer,
                        style: const TextStyle(color: FitCheckTheme.outline, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(quote, style: const TextStyle(color: FitCheckTheme.textSecondary, fontStyle: FontStyle.italic, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: FitCheckTheme.outline, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildDeltaProgressBar(String skill, double baseline, double latest, String delta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(skill, style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            Row(
              children: [
                Text('${(baseline * 100).toInt()}%', style: const TextStyle(color: FitCheckTheme.outline, fontSize: 11)),
                const Text(' → ', style: TextStyle(color: FitCheckTheme.outline, fontSize: 11)),
                Text('${(latest * 100).toInt()}%', style: const TextStyle(color: FitCheckTheme.tertiary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text('($delta)', style: const TextStyle(color: FitCheckTheme.tertiary, fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Baseline fill
            FractionallySizedBox(
              widthFactor: baseline,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: FitCheckTheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Latest fill
            FractionallySizedBox(
              widthFactor: latest,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: FitCheckTheme.tertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
