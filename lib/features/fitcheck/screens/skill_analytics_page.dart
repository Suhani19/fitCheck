import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class SkillAnalyticsPage extends StatelessWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final List<FitCheckSession> sessions;
  final List<FitCheckEvaluation> evaluations;
  final bool isDemoMode;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const SkillAnalyticsPage({
    super.key,
    this.candidate,
    this.currentUser,
    this.sessions = const [],
    this.evaluations = const [],
    this.isDemoMode = false,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final hasData = evaluations.isNotEmpty;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.skillAnalytics,
              candidate: candidate,
              currentUser: currentUser,
              onNavigate: onNavigate,
              onStartInterview: onStartInterview,
              onSignOut: onSignOut,
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
                          if (isDemoMode) _buildDemoModeNotice(),
                          _buildTitle(isDesktop),
                          const SizedBox(height: 24),
                          if (!hasData)
                            _buildEmptyState()
                          else ...[
                            _buildOverviewMetrics(isDesktop),
                            const SizedBox(height: 24),
                            _buildLongitudinalTrendSection(isDesktop),
                            const SizedBox(height: 24),
                            _buildCompetencyMatrix(isDesktop),
                            const SizedBox(height: 24),
                            _buildObservedInsightsSection(isDesktop),
                            const SizedBox(height: 24),
                            _buildSkillTagsSection(),
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

  Widget _buildDemoModeNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FitCheckTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: FitCheckTheme.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'DEMO PREVIEW: Displaying simulated sample evaluation metrics for candidate Elena. '
              'Real accounts calculate evidence-based metrics exclusively from your completed interview simulations.',
              style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 12),
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
                  icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurface, size: 20),
                  onPressed: () => onNavigate(FitCheckRoute.commandCenter),
                ),
                const SizedBox(width: 8),
              ],
              const FitCheckLogo(size: 16),
              const SizedBox(width: 8),
              Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 6),
              Text('Skill Analytics & Telemetry', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onStartInterview,
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
    );
  }

  Widget _buildTitle(bool isDesktop) {
    final candidateName = candidate?.fullName ?? (currentUser?.displayName ?? 'Candidate');
    final evalCount = evaluations.length;

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
              child: Text(
                isDemoMode ? 'SAMPLE DEMO RADAR' : 'EVIDENCE-BASED TELEMETRY',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CANDIDATE: ${candidateName.toUpperCase()}',
              style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
            ),
            if (evalCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '• $evalCount EVALUATED RUN${evalCount == 1 ? '' : 'S'}',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text('Skill Analytics & Competency Growth', style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Diagnostic tracking of architectural depth, fault tolerance, and communication composure grounded in actual interview transcript quotes.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined, size: 48, color: FitCheckTheme.outline),
          const SizedBox(height: 16),
          Text('No Skill Analytics Recorded Yet', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              'Complete your first interview simulation to generate competency benchmarks, rubric alignment breakdowns, and longitudinal growth tracking.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onStartInterview,
            icon: const Icon(Icons.mic, size: 16),
            label: const Text('Start First Simulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetrics(bool isDesktop) {
    final avgScore = evaluations.isNotEmpty
        ? (evaluations.map((e) => (e.overallScore <= 5.0 ? e.overallScore * 20 : e.overallScore)).reduce((a, b) => a + b) / evaluations.length).round()
        : 0;

    // Count unique competency dimensions evaluated across all sessions
    final uniqueCompetencies = <String>{};
    for (final ev in evaluations) {
      for (final comp in ev.competencyScores) {
        final name = comp['competency_name'] ?? comp['competency'];
        if (name != null) uniqueCompetencies.add(name.toString());
      }
    }

    final totalGaps = evaluations.fold<int>(0, (sum, ev) => sum + ev.technicalGaps.length);
    final completedSessionsCount = sessions.where((s) => s.status == 'ended' || s.status == 'completed').length;

    return Row(
      children: [
        Expanded(
          child: _metricBox(
            'AGGREGATE SCORE',
            '$avgScore%',
            evaluations.length == 1 ? 'Single session baseline' : 'Avg across ${evaluations.length} runs',
            FitCheckTheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox(
            'EVALUATED DIMENSIONS',
            '${uniqueCompetencies.length}',
            'Unique rubric criteria',
            FitCheckTheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox(
            'COMPLETED RUNS',
            '$completedSessionsCount',
            '${sessions.length} total initiated',
            FitCheckTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricBox(
            'IDENTIFIED GAPS',
            '$totalGaps',
            'Remediation areas',
            FitCheckTheme.warning,
          ),
        ),
      ],
    );
  }

  Widget _metricBox(String title, String val, String sub, Color col) {
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
          Text(title, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 4),
          Text(val, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface)),
          Text(sub, style: FitCheckTheme.labelSmall(color: col)),
        ],
      ),
    );
  }

  Widget _buildLongitudinalTrendSection(bool isDesktop) {
    if (evaluations.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.timeline_outlined, size: 20, color: FitCheckTheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LONGITUDINAL PROGRESSION (INSUFFICIENT HISTORICAL DATA)',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  const SizedBox(height: 2),
                  Text(
                    '1 simulation recorded. Complete at least 2 simulation runs to unlock score delta comparisons, trend trajectories, and multi-session velocity tracking.',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // With 2+ evaluations, compute evidence-backed delta
    final latest = evaluations.first;
    final earliest = evaluations.last;
    final latestScore = latest.overallScore <= 5.0 ? latest.overallScore * 20 : latest.overallScore;
    final earliestScore = earliest.overallScore <= 5.0 ? earliest.overallScore * 20 : earliest.overallScore;
    final delta = (latestScore - earliestScore).round();
    final isPositive = delta >= 0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LONGITUDINAL SCORE TRAJECTORY', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? FitCheckTheme.tertiary : FitCheckTheme.error).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isPositive ? '+$delta% Progress' : '$delta% Change',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? FitCheckTheme.tertiary : FitCheckTheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Session-over-Session Performance Progression', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(5, evaluations.length),
            separatorBuilder: (context, index) => const Divider(height: 16, color: FitCheckTheme.outlineVariant),
            itemBuilder: (context, idx) {
              final ev = evaluations[idx];
              final scorePct = (ev.overallScore <= 5.0 ? ev.overallScore * 20 : ev.overallScore).round();
              final dateStr = ev.createdAt != null && ev.createdAt!.length >= 10
                  ? ev.createdAt!.substring(0, 10)
                  : 'Simulation Run #${evaluations.length - idx}';

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('#${idx + 1}', style: const TextStyle(fontSize: 11, color: FitCheckTheme.outline)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ev.overallRecommendation, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
                          Text(dateStr, style: const TextStyle(fontSize: 11, color: FitCheckTheme.outline)),
                        ],
                      ),
                    ],
                  ),
                  Text('$scorePct%', style: FitCheckTheme.titleMedium().copyWith(color: scorePct >= 80 ? FitCheckTheme.tertiary : FitCheckTheme.primary)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyMatrix(bool isDesktop) {
    // Aggregate all unique competency scores across candidate evaluations
    final competencyAverages = <String, List<double>>{};

    for (final ev in evaluations) {
      for (final c in ev.competencyScores) {
        final name = (c['competency_name'] ?? c['competency'] ?? '').toString();
        if (name.isEmpty) continue;
        final raw = (c['score'] as num?)?.toDouble() ?? 3.5;
        final pct = (raw <= 5.0 ? raw / 5.0 : raw / 100.0).clamp(0.0, 1.0);
        competencyAverages.putIfAbsent(name, () => []).add(pct);
      }
    }

    final items = competencyAverages.entries.map((entry) {
      final meanPct = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return {
        'name': entry.key,
        'pct': meanPct,
        'label': '${(meanPct * 100).round()}%',
        'runs': entry.value.length,
      };
    }).toList();

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
          Text('AGGREGATED RUBRIC DIMENSIONS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 6),
          Text('Competency Alignment Breakdown', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'No individual competency breakdowns recorded for current evaluations.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
            )
          else
            ...items.map((it) {
              final pct = it['pct'] as double;
              final runs = it['runs'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${it['name']} ($runs evaluated run${runs == 1 ? '' : 's'})',
                            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
                        Text(it['label'] as String,
                            style: FitCheckTheme.labelSmall(
                                color: pct >= 0.8 ? FitCheckTheme.tertiary : FitCheckTheme.warning)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: FitCheckTheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 0.8 ? FitCheckTheme.tertiary : FitCheckTheme.primary),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildObservedInsightsSection(bool isDesktop) {
    final allStrengths = <String>{};
    final allGaps = <String>{};

    for (final ev in evaluations) {
      allStrengths.addAll(ev.observedStrengths);
      allGaps.addAll(ev.technicalGaps);
    }

    if (allStrengths.isEmpty && allGaps.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Text('TRANSCRIPT-GROUNDED OBSERVATIONS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 6),
          Text('Identified Strengths & Targeted Growth Areas', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 16),
          if (allStrengths.isNotEmpty) ...[
            Text('OBSERVED STRENGTHS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
            const SizedBox(height: 8),
            ...allStrengths.take(4).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: FitCheckTheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface))),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
          ],
          if (allGaps.isNotEmpty) ...[
            Text('REMEDIATION GAPS (FOCUS AREAS)', style: FitCheckTheme.labelSmall(color: FitCheckTheme.warning)),
            const SizedBox(height: 8),
            ...allGaps.take(4).map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: FitCheckTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(g, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillTagsSection() {
    final skills = candidate?.skills ?? <String>[];
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
          Text('VERIFIED CANDIDATE SKILL MATRIX', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 10),
          if (skills.isEmpty)
            Text(
              'No skills added to candidate profile yet. Update your profile in Candidate Profile to tag competencies.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(s, style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
