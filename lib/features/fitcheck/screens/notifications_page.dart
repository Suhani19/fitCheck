import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class NotificationsPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final List<FitCheckSession> sessions;
  final List<FitCheckEvaluation> evaluations;
  final bool isDemoMode;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const NotificationsPage({
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
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<Map<String, dynamic>> _notifications;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  @override
  void didUpdateWidget(NotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions || oldWidget.evaluations != widget.evaluations) {
      _initNotifications();
    }
  }

  void _initNotifications() {
    final list = <Map<String, dynamic>>[];

    for (final ev in widget.evaluations) {
      final scorePct = (ev.overallScore <= 5.0 ? ev.overallScore * 20 : ev.overallScore).round();
      list.add({
        'id': 'eval-${ev.id}',
        'title': 'Evaluation Ready: ${ev.overallRecommendation}',
        'body': 'Score: $scorePct% • ${ev.summaryVerdict.isNotEmpty ? ev.summaryVerdict : "Evaluation scorecard generated."}',
        'timestamp': 'Scorecard',
        'unread': true,
        'type': 'EVALUATION',
      });
    }

    for (final s in widget.sessions) {
      final hasEval = widget.evaluations.any((e) => e.sessionId == s.id);
      if (!hasEval) {
        list.add({
          'id': 'sess-${s.id}',
          'title': 'Simulation Recorded (${s.difficulty.toUpperCase()})',
          'body': 'Interview session ${s.id} recorded with status "${s.status}".',
          'timestamp': s.startedAt.isNotEmpty ? s.startedAt.split('T').first : 'Recent',
          'unread': false,
          'type': 'SYSTEM',
        });
      }
    }

    _notifications = list;
  }

  void _markAllAsRead() {
    setState(() {
      for (final n in _notifications) {
        n['unread'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final unreadCount = _notifications.where((n) => n['unread'] == true).length;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.notifications,
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
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(unreadCount),
                          const SizedBox(height: 24),
                          if (_notifications.isEmpty)
                            _buildEmptyState()
                          else
                            _buildNotificationList(),
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
              const FitCheckLogo(size: 16),
              const SizedBox(width: 8),
              Text('NOTIFICATIONS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Activity & Telemetry Feed', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          if (_notifications.isNotEmpty)
            OutlinedButton(
              key: const Key('mark_all_read_btn'),
              onPressed: _markAllAsRead,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FitCheckTheme.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              child: const Text('Mark all as read', style: TextStyle(fontSize: 12, color: FitCheckTheme.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle(int unreadCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Notifications', style: FitCheckTheme.headlineMedium()),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount NEW',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FitCheckTheme.primary),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Stay updated on completed interview evaluations, curriculum progress, and hardware checks.',
                style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
              ),
            ],
          ),
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
          const Icon(Icons.notifications_none_outlined, size: 48, color: FitCheckTheme.outline),
          const SizedBox(height: 16),
          Text('No Notifications Yet', style: FitCheckTheme.headlineMedium()),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'When you complete a live simulation session or receive an evidence-backed scorecard evaluation, updates will appear here.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const Key('notif_start_sim_btn'),
            onPressed: widget.onStartInterview,
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

  Widget _buildNotificationList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _notifications.length,
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        final unread = notif['unread'] as bool;

        return InkWell(
          onTap: () {
            setState(() => notif['unread'] = false);
            if (notif['type'] == 'EVALUATION') {
              widget.onNavigate(FitCheckRoute.history);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: unread
                  ? FitCheckTheme.surfaceContainerHigh
                  : FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: unread
                    ? FitCheckTheme.primary.withValues(alpha: 0.4)
                    : FitCheckTheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(
                      notif['type'] == 'EVALUATION'
                          ? Icons.assessment
                          : (notif['type'] == 'SYSTEM' ? Icons.check_circle : Icons.notifications),
                      size: 18,
                      color: unread ? FitCheckTheme.primary : FitCheckTheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif['title'] as String,
                              style: FitCheckTheme.titleMedium().copyWith(
                                fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            notif['timestamp'] as String,
                            style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif['body'] as String,
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
