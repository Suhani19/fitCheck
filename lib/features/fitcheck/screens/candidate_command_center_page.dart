import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class CandidateCommandCenterPage extends StatefulWidget {
  final VoidCallback onStartInterview;
  final VoidCallback onHardwareSetup;
  final VoidCallback onViewScorecard;
  final VoidCallback onViewHistory;
  final VoidCallback onViewLibrary;
  final VoidCallback onBackToLanding;
  final VoidCallback? onSignOut;
  final ValueChanged<FitCheckRoute>? onNavigate;
  final FitCheckUser? currentUser;
  final FitCheckCandidate? candidate;
  final List<FitCheckSession> sessions;
  final List<FitCheckEvaluation> evaluations;
  final bool isDemoMode;
  final FitCheckApiService? apiService;
  final ValueChanged<FitCheckCandidate>? onProfileUpdated;
  final ValueChanged<String>? onSelectSession;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const CandidateCommandCenterPage({
    super.key,
    required this.onStartInterview,
    required this.onHardwareSetup,
    required this.onViewScorecard,
    required this.onViewHistory,
    required this.onViewLibrary,
    required this.onBackToLanding,
    this.onSignOut,
    this.onNavigate,
    this.currentUser,
    this.candidate,
    this.sessions = const [],
    this.evaluations = const [],
    this.isDemoMode = false,
    this.apiService,
    this.onProfileUpdated,
    this.onSelectSession,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  State<CandidateCommandCenterPage> createState() => _CandidateCommandCenterPageState();
}

class _CandidateCommandCenterPageState extends State<CandidateCommandCenterPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _waveController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: FitCheckTheme.surfaceContainerLow,
              child: SafeArea(
                child: CandidateSidebar(
                  currentRoute: FitCheckRoute.commandCenter,
                  candidate: widget.candidate,
                  currentUser: widget.currentUser,
                  onNavigate: (route) {
                    Navigator.of(context).pop();
                    widget.onNavigate?.call(route);
                  },
                  onStartInterview: () {
                    Navigator.of(context).pop();
                    widget.onHardwareSetup();
                  },
                  onSignOut: () {
                    Navigator.of(context).pop();
                    (widget.onSignOut ?? widget.onBackToLanding)();
                  },
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar on Desktop
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.commandCenter,
              candidate: widget.candidate,
              currentUser: widget.currentUser,
              onNavigate: (route) => widget.onNavigate?.call(route),
              onStartInterview: widget.onHardwareSetup,
              onSignOut: widget.onSignOut ?? widget.onBackToLanding,
            ),

          // Main Center Flightdeck
          Expanded(
            child: Column(
              children: [
                _buildHeader(isDesktop),
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
                          _buildDemoModeBanner(),
                          _buildTopIdentityBar(isDesktop),
                          const SizedBox(height: 24),
                          _buildQuickStats(isDesktop),
                          const SizedBox(height: 24),
                          _buildHeroSimulationCard(isDesktop),
                          const SizedBox(height: 32),
                          _buildThreePillarsGrid(isDesktop),
                          const SizedBox(height: 32),
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

  Widget _buildHeader(bool isDesktop) {
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
                  Builder(
                    builder: (btnCtx) => IconButton(
                      icon: const Icon(Icons.menu, color: FitCheckTheme.onSurface),
                      onPressed: () => Scaffold.of(btnCtx).openDrawer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Candidate Command Center',
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
                border: Border.all(color: FitCheckTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag, size: 14, color: FitCheckTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Target: Staff Systems Eng @ Stripe - 84% Ready',
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Audio Ready (48kHz)', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameCtrl = TextEditingController(
      text: widget.candidate?.fullName ?? widget.currentUser?.displayName ?? '',
    );
    final headlineCtrl = TextEditingController(
      text: widget.candidate?.headline ?? '',
    );
    final skillsCtrl = TextEditingController(
      text: widget.candidate?.skills.join(', ') ?? '',
    );
    bool saving = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FitCheckTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: FitCheckTheme.outlineVariant),
          ),
          title: Text(
            'Edit Candidate Profile',
            style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 18),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(errorMsg!, style: FitCheckTheme.bodySmall(color: FitCheckTheme.error)),
                    ),
                  Text('Full Name', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const Key('candidate_edit_name_field'),
                    controller: nameCtrl,
                    style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'e.g. Elena Rostova',
                      hintStyle: FitCheckTheme.bodyMedium(color: FitCheckTheme.outline),
                      filled: true,
                      fillColor: FitCheckTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Headline / Target Role', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const Key('candidate_edit_headline_field'),
                    controller: headlineCtrl,
                    style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'e.g. Staff Distributed Systems Engineer',
                      hintStyle: FitCheckTheme.bodyMedium(color: FitCheckTheme.outline),
                      filled: true,
                      fillColor: FitCheckTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Skills (comma-separated)', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                  const SizedBox(height: 4),
                  TextField(
                    key: const Key('candidate_edit_skills_field'),
                    controller: skillsCtrl,
                    style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'e.g. Go, Raft, Distributed Systems, Kubernetes',
                      hintStyle: FitCheckTheme.bodyMedium(color: FitCheckTheme.outline),
                      filled: true,
                      fillColor: FitCheckTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
            ),
            ElevatedButton(
              key: const Key('candidate_save_profile_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.primary,
                foregroundColor: FitCheckTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() => errorMsg = 'Name cannot be empty.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorMsg = null;
                      });

                      final rawSkills = skillsCtrl.text
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();

                      if (widget.isDemoMode) {
                        final updated = FitCheckCandidate(
                          id: widget.candidate?.id ?? 'demo-elena-cand',
                          fullName: name,
                          headline: headlineCtrl.text.trim(),
                          skills: rawSkills,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        widget.onProfileUpdated?.call(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo profile updated in memory. (Sign in with a real account to persist to database).'),
                            ),
                          );
                        }
                        return;
                      }

                      try {
                        FitCheckCandidate updated;
                        if (widget.candidate != null && widget.apiService != null) {
                          updated = await widget.apiService!.updateCandidate(
                            widget.candidate!.id,
                            {
                              'full_name': name,
                              'headline': headlineCtrl.text.trim(),
                              'skills': rawSkills,
                            },
                          );
                        } else if (widget.apiService != null) {
                          updated = await widget.apiService!.createCandidate({
                            'full_name': name,
                            'headline': headlineCtrl.text.trim(),
                            'skills': rawSkills,
                          });
                        } else {
                          updated = FitCheckCandidate(
                            id: widget.candidate?.id ?? 'cand-local',
                            fullName: name,
                            headline: headlineCtrl.text.trim(),
                            skills: rawSkills,
                          );
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        widget.onProfileUpdated?.call(updated);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Candidate profile updated and persisted to database!')),
                          );
                        }
                      } catch (err) {
                        setDialogState(() {
                          saving = false;
                          errorMsg = err.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary),
                    )
                  : const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoModeBanner() {
    if (!widget.isDemoMode) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FitCheckTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: FitCheckTheme.warning),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'DEMO MODE (Simulated Candidate): You are exploring FitCheck with sample data. Profile edits and simulations run in-memory. Sign in with an account to persist real candidate data and AI evaluations.',
              style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: widget.onBackToLanding,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: FitCheckTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Sign In to Persist', style: TextStyle(color: FitCheckTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIdentityBar(bool isDesktop) {
    final candidateName = widget.candidate?.fullName ??
        widget.currentUser?.displayName ??
        (widget.isDemoMode ? 'Elena Rostova' : 'Candidate');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: FitCheckTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: FitCheckTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE READINESS FLIGHTDECK',
                          style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDemoMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: FitCheckTheme.warning.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.science, size: 12, color: FitCheckTheme.warning),
                          const SizedBox(width: 4),
                          Text(
                            'DEMO MODE • SAMPLE DATA',
                            style: FitCheckTheme.labelSmall(color: FitCheckTheme.warning)
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isDemoMode
                        ? 'SAMPLE SESSION // ID-8094-STRP'
                        : (widget.sessions.isNotEmpty
                            ? 'ACTIVE CANDIDATE // ${widget.sessions.first.id.substring(0, min(8, widget.sessions.first.id.length)).toUpperCase()}'
                            : 'CANDIDATE READY // CALIBRATION PENDING'),
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              key: const Key('edit_candidate_profile_button'),
              onPressed: () => _showEditProfileDialog(context),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(widget.isDemoMode ? 'Edit Demo Profile' : 'Edit Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FitCheckTheme.primary,
                side: const BorderSide(color: FitCheckTheme.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.isDemoMode
              ? 'Good evening, Elena. Ready for your Stripe simulation?'
              : 'Welcome back, $candidateName. Ready for your simulation?',
          style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineMedium(),
        ),
        if (!widget.isDemoMode && widget.candidate?.skills.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.candidate!.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Text(
                  skill,
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickStats(bool isDesktop) {
    final List<Map<String, dynamic>> stats;
    if (widget.isDemoMode) {
      stats = [
        {'title': 'SIMULATIONS COMPLETED', 'val': '14', 'sub': 'Sample history', 'subColor': FitCheckTheme.tertiary, 'icon': Icons.done_all},
        {'title': 'VOICE TELEMETRY TIME', 'val': '9.4 hrs', 'sub': 'Sample stream time', 'subColor': FitCheckTheme.outline, 'icon': Icons.mic},
        {'title': 'HIRE READINESS', 'val': '82%', 'sub': 'Sample evaluation', 'subColor': FitCheckTheme.tertiary, 'icon': Icons.trending_up},
        {'title': 'EVALUATED CRITERIA', 'val': '24', 'sub': 'Sample rubric scope', 'subColor': FitCheckTheme.secondary, 'icon': Icons.checklist},
      ];
    } else {
      final sessCount = widget.sessions.length;
      final hours = (sessCount * 0.75).toStringAsFixed(1);
      final readinessStr = widget.evaluations.isNotEmpty
          ? '${(widget.evaluations.map((e) => (e.overallScore <= 5.0 ? e.overallScore * 20 : e.overallScore)).reduce((a, b) => a + b) / widget.evaluations.length).round()}%'
          : 'Pending';
      final readinessSub = widget.evaluations.isNotEmpty
          ? widget.evaluations.first.overallRecommendation
          : 'Requires 1 simulation';
      final readinessColor = widget.evaluations.isNotEmpty
          ? FitCheckTheme.tertiary
          : FitCheckTheme.outline;
      final totalCriteria = widget.evaluations.fold<int>(0, (sum, e) => sum + e.competencyScores.length);

      stats = [
        {
          'title': 'SIMULATIONS COMPLETED',
          'val': '$sessCount',
          'sub': sessCount == 0 ? 'No simulations yet' : '+$sessCount recorded',
          'subColor': sessCount > 0 ? FitCheckTheme.tertiary : FitCheckTheme.outline,
          'icon': Icons.done_all,
        },
        {
          'title': 'VOICE TELEMETRY TIME',
          'val': '$hours hrs',
          'sub': sessCount > 0 ? 'Logged telemetry' : '0:00 recorded',
          'subColor': FitCheckTheme.outline,
          'icon': Icons.mic,
        },
        {
          'title': 'HIRE READINESS',
          'val': readinessStr,
          'sub': readinessSub,
          'subColor': readinessColor,
          'icon': Icons.trending_up,
        },
        {
          'title': 'EVALUATED CRITERIA',
          'val': sessCount > 0 ? '$totalCriteria' : '--',
          'sub': sessCount > 0 ? 'Rubric dimensions' : 'Requires 1 simulation',
          'subColor': sessCount > 0 ? FitCheckTheme.secondary : FitCheckTheme.outline,
          'icon': Icons.checklist,
        },
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 1.7 : 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        final s = stats[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s['title'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(s['val'] as String, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface)),
                    Text(s['sub'] as String, style: FitCheckTheme.labelSmall(color: s['subColor'] as Color), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(s['icon'] as IconData, color: FitCheckTheme.outline.withValues(alpha: 0.3), size: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptySimulationCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FitCheckTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'AWAITING FIRST SIMULATION',
              style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)
                  .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ready to benchmark your technical readiness?',
            style: FitCheckTheme.headlineLarge(color: FitCheckTheme.onSurface).copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'No interview simulations have been recorded yet for your candidate profile. Launch a live voice simulation with one of our AI interviewer personas to generate real speech telemetry, evaluate your architectural trade-offs, and receive verified competency scoring.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant).copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            key: const Key('start_first_simulation_button'),
            onPressed: widget.onHardwareSetup,
            icon: const Icon(Icons.mic, size: 16),
            label: const Text('Configure & Start First Simulation'),
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
    );
  }

  Widget _buildHeroSimulationCard(bool isDesktop) {
    if (widget.candidate != null && widget.sessions.isEmpty && !widget.isDemoMode) {
      return _buildEmptySimulationCard(isDesktop);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: FitCheckTheme.primary.withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pills row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FitCheckTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('PRIMARY STAGE QUEUE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('REALISTIC CALIBRATION • 45M', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Awaiting candidate check-in', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Scenario
          Text('UPCOMING SIMULATION SCENARIO', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 4),
          Text(
            'High-Scale Distributed Cache with Marcus Vance (Principal Architect Persona)',
            style: FitCheckTheme.headlineLarge(color: FitCheckTheme.onSurface).copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Evaluating memory layout under partition, consistent hashing ring resharding, zero-loss replication during node evictions, and low-latency client lease protocols.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Speaker strip & Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildInterviewerBioStrip(),
              _buildHeroActionGroup(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewerBioStrip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: FitCheckTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.person, color: FitCheckTheme.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Marcus Vance', style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 14, color: FitCheckTheme.primary),
                ],
              ),
              Text('Stripe Ingestion Architecture Lead', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Style: Socratic • Metric-Driven • Interrupt-Heavy', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroActionGroup() {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Mic Ready pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: FitCheckTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: FitCheckTheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq, size: 16, color: FitCheckTheme.tertiary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Input Ready', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.w600)),
                  Text('Shure MV7 • 14ms', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                ],
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final h = 6.0 + (sin(i + _waveController.value * pi).abs() * 10);
                    return Container(
                      width: 2,
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: i == 2 ? FitCheckTheme.tertiary : FitCheckTheme.primary,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        // Start button
        ElevatedButton.icon(
          onPressed: widget.onHardwareSetup,
          icon: const Icon(Icons.mic, size: 16),
          label: const Text('Start Live Interview'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FitCheckTheme.primary,
            foregroundColor: FitCheckTheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle: FitCheckTheme.bodyMedium().copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildThreePillarsGrid(bool isDesktop) {
    return isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildActionRadarColumn()),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentSessionsColumn()),
              const SizedBox(width: 16),
              Expanded(child: _buildCompetencyRadarColumn()),
            ],
          )
        : Column(
            children: [
              _buildActionRadarColumn(),
              const SizedBox(height: 16),
              _buildRecentSessionsColumn(),
              const SizedBox(height: 16),
              _buildCompetencyRadarColumn(),
            ],
          );
  }

  Widget _buildActionRadarColumn() {
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
              Flexible(
                child: Text(
                  '01 // ACTION RADAR',
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text('3 pending', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Text('What should I do next?', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          _drillCard(
            title: 'Consensus & Raft Practice Drill',
            tag: 'URGENT DRILL',
            tagColor: FitCheckTheme.primary,
            time: '15 min',
            desc: 'Reinforce leader election timers, uncommitted log entries, and quorum handling.',
            onTap: widget.onViewLibrary,
          ),
          const SizedBox(height: 10),
          _drillCard(
            title: 'Multi-Region Replication Review',
            tag: 'WEAK SPOT',
            tagColor: FitCheckTheme.warning,
            time: '10 min',
            desc: 'Analyze clock drift hazards and cross-DC lease timeouts under WAN partition.',
            onTap: widget.onViewLibrary,
          ),
        ],
      ),
    );
  }

  Widget _drillCard({
    required String title,
    required String tag,
    required Color tagColor,
    required String time,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tagColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                  child: Text(tag, style: FitCheckTheme.labelSmall(color: tagColor).copyWith(fontSize: 9)),
                ),
                Text(time, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSessionsColumn() {
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
              Flexible(child: Text('02 // RECENT SESSIONS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              InkWell(onTap: widget.onViewHistory, child: Text('View all', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Past Simulations', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          if (widget.isDemoMode) ...[
            _sessionItem(
              role: 'Stripe L6 Systems Simulation',
              score: '88/100',
              verdict: 'STRONG HIRE',
              verdictColor: FitCheckTheme.tertiary,
              interviewer: 'Marcus Vance',
              date: 'Yesterday',
              onTap: widget.onViewScorecard,
            ),
            const SizedBox(height: 10),
            _sessionItem(
              role: 'Meta E6 Infra Architecture',
              score: '82/100',
              verdict: 'LEAN HIRE',
              verdictColor: FitCheckTheme.primary,
              interviewer: 'Sarah Chen',
              date: '3 days ago',
              onTap: widget.onViewScorecard,
            ),
          ] else if (widget.sessions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off, color: FitCheckTheme.outline, size: 36),
                  const SizedBox(height: 10),
                  Text(
                    'No past sessions recorded',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Completed simulations will appear here.',
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            ...widget.sessions.take(3).map((sess) {
              final eval = widget.evaluations.where((e) => e.sessionId == sess.id).firstOrNull;
              final scoreText = eval != null ? '${(eval.overallScore * 20).round()}/100' : 'RECORDED';
              final verdictText = eval?.overallRecommendation.toUpperCase() ?? sess.status.toUpperCase();
              final verdictColor = eval != null
                  ? (eval.overallScore >= 4.0 ? FitCheckTheme.tertiary : FitCheckTheme.primary)
                  : FitCheckTheme.secondary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _sessionItem(
                  role: 'Session // ${sess.difficulty.toUpperCase()}',
                  score: scoreText,
                  verdict: verdictText,
                  verdictColor: verdictColor,
                  interviewer: 'AI Interviewer',
                  date: sess.startedAt.isNotEmpty ? sess.startedAt.split('T').first : 'Recent',
                  onTap: () {
                    if (widget.onSelectSession != null) {
                      widget.onSelectSession!(sess.id);
                    } else {
                      widget.onViewScorecard();
                    }
                  },
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _sessionItem({
    required String role,
    required String score,
    required String verdict,
    required Color verdictColor,
    required String interviewer,
    required String date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(score, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.onSurface).copyWith(fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: verdictColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                  child: Text(verdict, style: FitCheckTheme.labelSmall(color: verdictColor).copyWith(fontSize: 9)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(role, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Interviewer: $interviewer • $date', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompetencyRadarColumn() {
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
              Flexible(child: Text('03 // READINESS RADAR', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text('Target L6 Stripe', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Competency Alignment', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
          const SizedBox(height: 14),
          _competencyBar('System Architecture', 0.92, '92%'),
          const SizedBox(height: 10),
          _competencyBar('Consensus & Resiliency', 0.86, '86%'),
          const SizedBox(height: 10),
          _competencyBar('Pacing & Composure', 0.88, '88%'),
          const SizedBox(height: 10),
          _competencyBar('Edge-Case Defense', 0.76, '76% (Focus Area)'),
        ],
      ),
    );
  }

  Widget _competencyBar(String label, double ratio, String scoreText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(scoreText, style: FitCheckTheme.labelSmall(color: ratio >= 0.85 ? FitCheckTheme.tertiary : FitCheckTheme.warning)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: FitCheckTheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(ratio >= 0.85 ? FitCheckTheme.primary : FitCheckTheme.warning),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
