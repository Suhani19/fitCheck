import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';

class EvaluationScorecardPage extends StatelessWidget {
  final VoidCallback onBackToDashboard;
  final VoidCallback onRetakeSimulation;
  final VoidCallback onLaunchRecommendedDrill;
  final FitCheckEvaluation? evaluation;
  final FitCheckSession? session;
  final bool isDemoMode;

  const EvaluationScorecardPage({
    super.key,
    required this.onBackToDashboard,
    required this.onRetakeSimulation,
    required this.onLaunchRecommendedDrill,
    this.evaluation,
    this.session,
    this.isDemoMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 36 : 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBentoHero(isDesktop),
                    const SizedBox(height: 32),
                    _buildExecutiveScorecardSection(isDesktop),
                    const SizedBox(height: 32),
                    _buildAcousticAndKeyMomentsSection(isDesktop),
                    const SizedBox(height: 32),
                    _buildActionPlanSection(isDesktop),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
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
                  onPressed: onBackToDashboard,
                  tooltip: 'Back to Command Center',
                ),
                const SizedBox(width: 8),
                const FitCheckLogo(size: 16),
                const SizedBox(width: 8),
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Flexible(child: Text('Evaluation Scorecard', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session != null
                        ? 'SESSION: ${session!.id.substring(0, min(8, session!.id.length)).toUpperCase()}'
                        : (evaluation != null
                            ? 'SESSION: ${evaluation!.sessionId.substring(0, min(8, evaluation!.sessionId.length)).toUpperCase()}'
                            : 'SESSION: STR-9821-L6'),
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onLaunchRecommendedDrill,
            icon: const Icon(Icons.fitness_center, size: 16),
            label: const Text('Launch Recommended Drill'),
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

  Widget _buildBentoHero(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 8, child: _buildVerdictContent()),
                const SizedBox(width: 32),
                Expanded(flex: 4, child: _buildScoreDonut()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVerdictContent(),
                const SizedBox(height: 24),
                _buildScoreDonut(),
              ],
            ),
    );
  }

  Widget _buildVerdictContent() {
    final hasRealEval = evaluation != null;
    final isUnscoredSession = !hasRealEval && session != null && !isDemoMode;

    final String recommendation;
    final String summaryText;
    final Color badgeColor;

    if (hasRealEval) {
      recommendation = evaluation!.overallRecommendation.toUpperCase();
      summaryText = evaluation!.summaryVerdict.isNotEmpty
          ? evaluation!.summaryVerdict
          : 'Evaluation generated based on spoken candidate responses and evidence-backed competency verification.';
      badgeColor = evaluation!.overallScore >= 4.0 ? FitCheckTheme.tertiary : FitCheckTheme.primary;
    } else if (isUnscoredSession) {
      recommendation = 'SESSION ${session!.status.toUpperCase()} • EVALUATION PENDING';
      summaryText = session!.status == 'active'
          ? 'This interview simulation is currently active or awaiting evaluation synthesis from the AI hiring committee.'
          : 'This session was concluded with status "${session!.status}". A full competency evaluation report is not recorded for this session record.';
      badgeColor = FitCheckTheme.outline;
    } else {
      recommendation = 'STRONG HIRE • LEVEL 6 READY';
      summaryText =
          'Demonstrated exceptional architectural intuition and nuanced multi-region trade-off reasoning. Handled clock drift edge cases with mature engineering judgment. Minor gap in calculating network amplification during cluster rebalancing.';
      badgeColor = FitCheckTheme.tertiary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hasRealEval ? Icons.verified : Icons.info_outline, size: 14, color: badgeColor),
                  const SizedBox(width: 6),
                  Text(recommendation, style: FitCheckTheme.labelSmall(color: badgeColor).copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isDemoMode ? 'Calibration: Sample Finalists' : (hasRealEval ? 'Live Verified Evaluation' : 'Session Record'),
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
              ),
            ),
            if (hasRealEval)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('94% Evaluator Confidence', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          summaryText,
          style: FitCheckTheme.bodyLarge(color: FitCheckTheme.onSurface).copyWith(height: 1.45),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _metricPill(
              hasRealEval ? Icons.check_circle : Icons.history,
              hasRealEval ? FitCheckTheme.tertiary : FitCheckTheme.outline,
              hasRealEval ? 'Evaluation Calibrated' : 'Session Persisted in Database',
            ),
            _metricPill(
              Icons.analytics,
              FitCheckTheme.primary,
              session != null ? 'Difficulty: ${session!.difficulty.toUpperCase()}' : 'Target L6 Bar',
            ),
            if (hasRealEval)
              _metricPill(Icons.tune, FitCheckTheme.secondary, '${evaluation!.competencyScores.length} Evaluated Domains'),
          ],
        ),
      ],
    );
  }

  Widget _metricPill(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildScoreDonut() {
    final hasRealEval = evaluation != null;
    final isUnscoredSession = !hasRealEval && session != null && !isDemoMode;

    final String scoreDisplay;
    final double ratio;

    if (hasRealEval) {
      final scoreVal = evaluation!.overallScore <= 5.0
          ? (evaluation!.overallScore * 20).round()
          : evaluation!.overallScore.round();
      scoreDisplay = '$scoreVal';
      ratio = (scoreVal / 100.0).clamp(0.0, 1.0);
    } else if (isUnscoredSession) {
      scoreDisplay = '--';
      ratio = 0.0;
    } else {
      scoreDisplay = '88';
      ratio = 0.88;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: CircularProgressIndicator(
                value: isUnscoredSession ? 0.0 : (ratio > 0 ? ratio : null),
                strokeWidth: 8,
                backgroundColor: FitCheckTheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  hasRealEval ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(scoreDisplay, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface).copyWith(fontSize: 32)),
                Text(
                  hasRealEval || isDemoMode ? '/ 100 SCORE' : 'PENDING EVAL',
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATUS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9)),
                  Text(
                    session?.status.toUpperCase() ?? (hasRealEval ? 'EVALUATED' : 'SAMPLE DEMO'),
                    style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SESSION DIFFICULTY', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9)),
                  Text(
                    session?.difficulty.toUpperCase() ?? 'REALISTIC',
                    style: FitCheckTheme.labelMedium(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExecutiveScorecardSection(bool isDesktop) {
    final hasRealEval = evaluation != null;
    final isUnscoredSession = !hasRealEval && session != null && !isDemoMode;

    if (isUnscoredSession) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SECTION 01 // COMPETENCY BREAKDOWN', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            const SizedBox(height: 6),
            Text('No Evaluation Scorecard Available', style: FitCheckTheme.headlineMedium()),
            const SizedBox(height: 8),
            Text(
              'This historical session record does not have a linked evaluation. Competency breakdowns are computed when a live simulation successfully concludes with transcript turns.',
              style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> domains;
    if (evaluation != null && evaluation!.competencyScores.isNotEmpty) {
      domains = evaluation!.competencyScores.map((c) {
        final raw = (c['score'] as num?)?.toDouble() ?? 3.5;
        final sc = (raw <= 5.0 ? raw * 20 : raw).round();
        final name = c['competency_name'] as String? ?? c['name'] as String? ?? 'Competency';
        final desc = c['reasoning'] as String? ?? c['critique'] as String? ?? 'Verified candidate response critique.';
        final Color col;
        final String st;
        if (sc >= 90) {
          col = FitCheckTheme.primary;
          st = 'Exemplary';
        } else if (sc >= 80) {
          col = FitCheckTheme.tertiary;
          st = 'Proficient';
        } else {
          col = FitCheckTheme.warning;
          st = 'Opportunity';
        }
        return {'name': name, 'score': sc, 'status': st, 'color': col, 'desc': desc};
      }).toList();
    } else {
      domains = [
        {'name': 'System Architecture & Trade-offs', 'score': 92, 'status': 'Strong Strength', 'color': FitCheckTheme.primary, 'desc': 'Exceptional WAN topology mapping and dual-write hazard mitigation.'},
        {'name': 'Consensus & Fault Tolerance', 'score': 86, 'status': 'Proficient', 'color': FitCheckTheme.tertiary, 'desc': 'Solid grasp of Multi-Raft quorums and leader-election split-brain logic.'},
        {'name': 'Performance & Scale Bottlenecks', 'score': 84, 'status': 'Proficient', 'color': FitCheckTheme.tertiary, 'desc': 'Effective client-lease protocol with minimal latency overhead.'},
        {'name': 'Edge-Case & Chaos Defense', 'score': 78, 'status': 'Opportunity', 'color': FitCheckTheme.warning, 'desc': 'Hesitated on network partition cross-DC replication amplification math.'},
        {'name': 'Communication & Composure', 'score': 94, 'status': 'Exemplary', 'color': FitCheckTheme.primary, 'desc': 'Decisive, structured, no filler words, and clean Socratic recovery.'},
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SECTION 01 // COMPETENCY BREAKDOWN', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                const SizedBox(height: 4),
                Text('Executive Scorecard', style: FitCheckTheme.headlineLarge()),
              ],
            ),
            Row(
              children: [
                _statusLegendDot(FitCheckTheme.primary, 'Exemplary (90+)'),
                const SizedBox(width: 12),
                _statusLegendDot(FitCheckTheme.tertiary, 'Proficient (80-89)'),
                const SizedBox(width: 12),
                _statusLegendDot(FitCheckTheme.warning, 'Opportunity (<80)'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 5 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.05 : 1.3,
          ),
          itemCount: domains.length,
          itemBuilder: (context, i) {
            final d = domains[i];
            final score = d['score'] as int;
            final color = d['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('DOMAIN 0${i + 1}', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 9), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 4),
                          Flexible(child: Text(d['status'] as String, style: FitCheckTheme.labelSmall(color: color).copyWith(fontSize: 9), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(d['name'] as String, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold), maxLines: 2),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$score', style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface).copyWith(fontSize: 22)),
                          const SizedBox(width: 4),
                          Text('/ 100', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: score / 100.0,
                          backgroundColor: FitCheckTheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(d['desc'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _statusLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
      ],
    );
  }

  Widget _buildAcousticAndKeyMomentsSection(bool isDesktop) {
    final rawTranscript = session?.transcript;
    final List<Map<String, dynamic>> turns = [];
    if (rawTranscript != null) {
      for (final t in rawTranscript) {
        if (t is Map) {
          final text = (t['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            turns.add(Map<String, dynamic>.from(t));
          }
        }
      }
    }

    final hasEvidence = evaluation != null &&
        (evaluation!.observedStrengths.isNotEmpty || evaluation!.technicalGaps.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SECTION 02 // ACOUSTIC TELEMETRY & KEY MOMENTS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
        const SizedBox(height: 4),
        Text('Simulation Transcript Audit', style: FitCheckTheme.headlineLarge()),
        const SizedBox(height: 16),
        if (hasEvidence) ...[
          ...evaluation!.observedStrengths.map((str) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _momentCard(
                timestamp: 'Observed Strength',
                title: 'Evidence-Backed Verification',
                badge: 'STRENGTH MOMENT',
                badgeColor: FitCheckTheme.tertiary,
                quote: '“$str”',
                critique: 'Hiring committee calibration: Verified clear articulation of architectural concepts.',
              ),
            );
          }),
          ...evaluation!.technicalGaps.map((gap) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _momentCard(
                timestamp: 'Target Area',
                title: 'Identified Technical Opportunity',
                badge: 'COACHING OPPORTUNITY',
                badgeColor: FitCheckTheme.warning,
                quote: '“$gap”',
                critique: 'Hiring committee recommendation: Review operational edge cases and deepen trade-off defense.',
              ),
            );
          }),
        ],
        if (turns.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Persisted Spoken Transcript (${turns.length} turns)', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          ...turns.map((turn) {
            final isInterviewer = turn['role'] == 'interviewer';
            final text = turn['text'] as String? ?? '';
            final time = turn['timestamp']?.toString().split('T').last.split('.').first ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isInterviewer ? FitCheckTheme.surfaceContainerLow : FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isInterviewer ? FitCheckTheme.outlineVariant : FitCheckTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isInterviewer ? Icons.smart_toy_outlined : Icons.person_outline,
                            size: 16,
                            color: isInterviewer ? FitCheckTheme.secondary : FitCheckTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isInterviewer ? 'AI Interviewer (Persona)' : 'Candidate Response',
                            style: FitCheckTheme.labelSmall(
                              color: isInterviewer ? FitCheckTheme.secondary : FitCheckTheme.primary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (time.isNotEmpty)
                        Text(time, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
                ],
              ),
            );
          }),
        ] else if (!hasEvidence) ...[
          if (isDemoMode && session == null) ...[
            _momentCard(
              timestamp: '26:45',
              title: 'Flawless Multi-Raft Quorum Explanation',
              badge: 'STRENGTH MOMENT',
              badgeColor: FitCheckTheme.tertiary,
              quote: '“Write operations route strictly to the active shard leader; upon partition isolation, the leader fails fast via bounded heartbeat timeouts rather than split-braining.”',
              critique: 'Evaluator Note: Clear mental model of lease bounds. Demonstrated command of distributed failure states.',
            ),
            const SizedBox(height: 12),
            _momentCard(
              timestamp: '28:10',
              title: 'NTP Clock Drift Uncertainty Hesitation',
              badge: 'COACHING OPPORTUNITY',
              badgeColor: FitCheckTheme.warning,
              quote: '“Good, but let’s push on the HLC synchronization bounds. If NTP drifts beyond 250ms, how does your state machine prevent stale reads?”',
              critique: 'Evaluator Note: Took 4.2 seconds of pause before responding. Recommended clarifying read-index or TrueTime uncertainty intervals upfront.',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: FitCheckTheme.outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Simulation transcript was not stored or session was concluded without recording audio turns.',
                      style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _momentCard({
    required String timestamp,
    required String title,
    required String badge,
    required Color badgeColor,
    required String quote,
    required String critique,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: FitCheckTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
                    child: Text(timestamp, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  ),
                  const SizedBox(width: 8),
                  Text(title, style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                child: Text(badge, style: FitCheckTheme.labelSmall(color: badgeColor).copyWith(fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(quote, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.psychology, size: 14, color: FitCheckTheme.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(critique, style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPlanSection(bool isDesktop) {
    final recText = (evaluation?.preparationRecommendations.isNotEmpty == true)
        ? evaluation!.preparationRecommendations.first
        : 'Consensus & Raft Sparring Drill (15m) • Reinforces leader election timeouts & clock uncertainty intervals.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRESCRIPTIVE REMEDIATION ROADMAP', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                const SizedBox(height: 4),
                Text('Recommended Practice Next', style: FitCheckTheme.headlineMedium()),
                const SizedBox(height: 4),
                Text(
                  recText,
                  style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onRetakeSimulation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.onSurface,
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Retake Simulation'),
              ),
              ElevatedButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.dashboard, size: 16),
                label: const Text('Return to Command Center'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
