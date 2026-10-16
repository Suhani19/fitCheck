import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class LearningPlanPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final List<FitCheckEvaluation> evaluations;
  final List<FitCheckSession> sessions;
  final bool isDemoMode;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const LearningPlanPage({
    super.key,
    this.candidate,
    this.currentUser,
    this.evaluations = const [],
    this.sessions = const [],
    this.isDemoMode = false,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  State<LearningPlanPage> createState() => _LearningPlanPageState();
}

class _LearningPlanPageState extends State<LearningPlanPage> {
  bool _showSamplePreview = false;
  Set<String> _completedMilestoneIds = <String>{};
  bool _loadingSavedState = true;

  String get _storageKey {
    final uid = widget.currentUser?.uid ?? 'anon';
    final cid = widget.candidate?.id ?? 'local';
    return 'fitcheck_learning_milestones_${uid}_$cid';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedMilestones();
  }

  @override
  void didUpdateWidget(LearningPlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate?.id != widget.candidate?.id ||
        oldWidget.currentUser?.uid != widget.currentUser?.uid) {
      _loadSavedMilestones();
    }
  }

  Future<void> _loadSavedMilestones() async {
    setState(() => _loadingSavedState = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_storageKey) ?? [];
      if (mounted) {
        setState(() {
          _completedMilestoneIds = saved.toSet();
          _loadingSavedState = false;
        });
      }
    } catch (e) {
      debugPrint('[LearningPlan] Error loading saved milestones: $e');
      if (mounted) setState(() => _loadingSavedState = false);
    }
  }

  Future<void> _toggleMilestone(String milestoneId) async {
    setState(() {
      if (_completedMilestoneIds.contains(milestoneId)) {
        _completedMilestoneIds.remove(milestoneId);
      } else {
        _completedMilestoneIds.add(milestoneId);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _completedMilestoneIds.toList());
    } catch (e) {
      debugPrint('[LearningPlan] Error persisting milestone state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to persist milestone: $e'),
            backgroundColor: FitCheckTheme.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _buildRealPhases() {
    if (widget.evaluations.isEmpty) return [];

    final ev = widget.evaluations.first;
    final phases = <Map<String, dynamic>>[];

    // Phase 1: Remediate Identified Gaps
    if (ev.technicalGaps.isNotEmpty) {
      final items = ev.technicalGaps.asMap().entries.map((entry) {
        final id = 'gap_${entry.key}_${entry.value.hashCode}';
        final isDone = _completedMilestoneIds.contains(id);
        return {
          'id': id,
          'name': entry.value,
          'done': isDone,
        };
      }).toList();

      final doneCount = items.where((i) => i['done'] == true).length;
      final progress = items.isNotEmpty ? doneCount / items.length : 0.0;

      phases.add({
        'phase': 'Phase 1',
        'title': 'Remediate Technical Gaps',
        'status': progress >= 1.0 ? 'COMPLETED' : (progress > 0.0 ? 'IN_PROGRESS' : 'UPCOMING'),
        'progress': progress,
        'items': items,
      });
    }

    // Phase 2: Prescriptive Preparation Recommendations
    if (ev.preparationRecommendations.isNotEmpty) {
      final items = ev.preparationRecommendations.asMap().entries.map((entry) {
        final id = 'rec_${entry.key}_${entry.value.hashCode}';
        final isDone = _completedMilestoneIds.contains(id);
        return {
          'id': id,
          'name': entry.value,
          'done': isDone,
        };
      }).toList();

      final doneCount = items.where((i) => i['done'] == true).length;
      final progress = items.isNotEmpty ? doneCount / items.length : 0.0;

      phases.add({
        'phase': 'Phase 2',
        'title': 'Prescriptive Preparation Drills',
        'status': progress >= 1.0 ? 'COMPLETED' : (progress > 0.0 ? 'IN_PROGRESS' : 'UPCOMING'),
        'progress': progress,
        'items': items,
      });
    }

    // Phase 3: Core Competencies Calibration
    if (ev.competencyScores.isNotEmpty) {
      final items = ev.competencyScores.asMap().entries.map((entry) {
        final c = entry.value;
        final name = c['competency_name'] ?? c['competency'] ?? 'Architectural Depth';
        final score = (c['score'] as num?)?.toDouble() ?? 3.0;
        final id = 'comp_${entry.key}_${name.hashCode}';
        final autoMastered = score >= 4.0;
        final isDone = autoMastered || _completedMilestoneIds.contains(id);
        return {
          'id': id,
          'name': '$name (Evaluated Score: $score/5.0)',
          'done': isDone,
        };
      }).toList();

      final doneCount = items.where((i) => i['done'] == true).length;
      final progress = items.isNotEmpty ? doneCount / items.length : 0.0;

      phases.add({
        'phase': 'Phase 3',
        'title': 'Core Competency Mastery',
        'status': progress >= 1.0 ? 'COMPLETED' : (progress > 0.0 ? 'IN_PROGRESS' : 'UPCOMING'),
        'progress': progress,
        'items': items,
      });
    }

    return phases;
  }

  List<Map<String, dynamic>> _samplePhases() {
    return [
      {
        'phase': 'Phase 1 (Sample Preview)',
        'title': 'Consensus & State Machine Replication Foundations',
        'status': 'IN_PROGRESS',
        'progress': 0.66,
        'items': [
          {'id': 'sample_1', 'name': 'Raft leader election heartbeat timeout tuning', 'done': true},
          {'id': 'sample_2', 'name': 'Linearizable read lease mechanics vs state machine reads', 'done': true},
          {'id': 'sample_3', 'name': 'Log compaction snapshotting with zero-downtime checkpoints', 'done': false},
        ],
      },
      {
        'phase': 'Phase 2 (Sample Preview)',
        'title': 'Storage Engine & WAL Compaction Under Concurrency',
        'status': 'UPCOMING',
        'progress': 0.0,
        'items': [
          {'id': 'sample_4', 'name': 'Append-only write-ahead log flush semantics (O_DIRECT vs sync)', 'done': false},
          {'id': 'sample_5', 'name': 'LSM-tree write stalls during level-0 compaction storms', 'done': false},
          {'id': 'sample_6', 'name': 'Lock-free ring buffer implementation for bounded queuing', 'done': false},
        ],
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final realPhases = _buildRealPhases();
    final hasRealData = realPhases.isNotEmpty;
    final phasesToDisplay = hasRealData ? realPhases : (_showSamplePreview ? _samplePhases() : <Map<String, dynamic>>[]);

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.learningPlan,
              candidate: widget.candidate,
              currentUser: widget.currentUser,
              onNavigate: widget.onNavigate,
              onStartInterview: widget.onStartInterview,
              onSignOut: widget.onSignOut,
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, isDesktop),
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
                          _buildTitle(hasRealData),
                          const SizedBox(height: 16),
                          _buildPersistenceScopeNotice(),
                          const SizedBox(height: 20),
                          if (_loadingSavedState)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(color: FitCheckTheme.primary),
                              ),
                            )
                          else if (!hasRealData && !_showSamplePreview)
                            _buildEmptyState()
                          else ...[
                            _buildProgressBanner(phasesToDisplay, hasRealData),
                            const SizedBox(height: 24),
                            ...phasesToDisplay.map((p) => _buildPhaseCard(p, hasRealData)),
                          ],
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

  Widget _buildPersistenceScopeNotice() {
    final candidateId = widget.candidate?.id ?? 'local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: FitCheckTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PERSISTENCE SCOPE: Learning milestones are stored with candidate tenant isolation (Candidate ID: $candidateId). '
              'Toggling objectives persists your progress locally across sessions. Backend cloud synchronization for learning plans is documented in FITCHECK_MIGRATION_PLAN.md.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
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
          Row(
            children: [
              if (!isDesktop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurfaceVariant),
                  onPressed: () => widget.onNavigate(FitCheckRoute.commandCenter),
                ),
                const SizedBox(width: 8),
              ],
              Text('LEARNING PLAN', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Remediation & Mastery Roadmap', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          ElevatedButton.icon(
            key: const Key('plan_start_interview_header_btn'),
            onPressed: widget.onStartInterview,
            icon: const Icon(Icons.mic, size: 14),
            label: const Text('Start Next Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(bool hasRealData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Personalized Learning Roadmap', style: FitCheckTheme.headlineMedium()),
            if (!hasRealData && _showSamplePreview) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FitCheckTheme.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SAMPLE PREVIEW ONLY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FitCheckTheme.secondary)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasRealData
              ? 'Targeted curriculum derived dynamically from your simulation scorecard evaluations. Tap milestones to toggle completion.'
              : 'Actionable practice syllabus generated from candidate interview evaluation gaps.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.school_outlined, size: 48, color: FitCheckTheme.outline),
          const SizedBox(height: 16),
          Text('No Learning Plan Generated Yet', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Complete your first interview simulation to generate a calibrated learning plan derived from your actual evaluation gaps, technical blind spots, and rubric recommendations.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                key: const Key('plan_start_first_sim_btn'),
                onPressed: widget.onStartInterview,
                icon: const Icon(Icons.mic, size: 16),
                label: const Text('Start First Simulation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                key: const Key('plan_preview_sample_btn'),
                onPressed: () => setState(() => _showSamplePreview = true),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview Sample Syllabus'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBanner(List<Map<String, dynamic>> phases, bool hasRealData) {
    var totalItems = 0;
    var completedItems = 0;
    for (final p in phases) {
      final items = p['items'] as List<dynamic>? ?? [];
      totalItems += items.length;
      completedItems += items.where((i) => i['done'] == true).length;
    }

    final pct = totalItems > 0 ? (completedItems / totalItems) : 0.0;
    final pctText = '${(pct * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hasRealData ? 'CURRICULUM ACTIVE • $pctText' : 'PREVIEW CURRICULUM • $pctText',
                            style: const TextStyle(
                              color: FitCheckTheme.tertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('$completedItems of $totalItems Objectives Completed', style: FitCheckTheme.bodySmall()),
                      ],
                    ),
                    if (!hasRealData)
                      TextButton(
                        onPressed: () => setState(() => _showSamplePreview = false),
                        child: const Text('Hide Sample Preview', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: FitCheckTheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(FitCheckTheme.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseCard(Map<String, dynamic> phase, bool hasRealData) {
    final status = phase['status'] as String;
    final isDone = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS';
    final items = phase['items'] as List<dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInProgress ? FitCheckTheme.primary.withValues(alpha: 0.4) : FitCheckTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase['phase'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                    const SizedBox(height: 4),
                    Text(phase['title'] as String, style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? FitCheckTheme.tertiary.withValues(alpha: 0.15)
                        : (isInProgress
                            ? FitCheckTheme.primary.withValues(alpha: 0.15)
                            : FitCheckTheme.surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDone ? FitCheckTheme.tertiary : (isInProgress ? FitCheckTheme.primary : FitCheckTheme.outline),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: items.map((item) {
                final done = item['done'] as bool;
                final id = item['id'] as String;

                return InkWell(
                  key: Key('milestone_row_$id'),
                  onTap: hasRealData ? () => _toggleMilestone(id) : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          done ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: done ? FitCheckTheme.tertiary : FitCheckTheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['name'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              color: done ? FitCheckTheme.onSurfaceVariant : FitCheckTheme.onSurface,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (hasRealData)
                          Text(
                            done ? 'Completed' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              color: done ? FitCheckTheme.tertiary : FitCheckTheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
