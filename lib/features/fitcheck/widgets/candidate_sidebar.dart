import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../screens/fitcheck_shell.dart';

/// Reusable sidebar for authenticated FitCheck candidates.
/// Adheres strictly to the Stitch Precision Studio Dark-Mode design system.
/// Landing Page is deliberately excluded from authenticated candidate navigation.
class CandidateSidebar extends StatelessWidget {
  final FitCheckRoute currentRoute;
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const CandidateSidebar({
    super.key,
    required this.currentRoute,
    this.candidate,
    this.currentUser,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
      ),
      child: Column(
        children: [
          // Logo header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: const Center(
                    child: Icon(Icons.mic, color: FitCheckTheme.primary, size: 16),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FitCheck',
                        style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'GET FIT. CHECK FIT.',
                        style: FitCheckTheme.labelSmall().copyWith(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Primary Quick Action: Start Interview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('sidebar_start_interview_button'),
                onPressed: onStartInterview,
                icon: const Icon(Icons.mic, size: 16),
                label: const Text('Start Interview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildSectionHeader('OVERVIEW'),
                _buildSidebarItem(
                  icon: Icons.grid_view,
                  label: 'Dashboard',
                  route: FitCheckRoute.commandCenter,
                ),

                const SizedBox(height: 8),
                _buildSectionHeader('PREPARE'),
                _buildSidebarItem(
                  icon: Icons.work_outline,
                  label: 'Target Jobs & Rubrics',
                  route: FitCheckRoute.targetJobs,
                ),
                _buildSidebarItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Interviewer Library',
                  route: FitCheckRoute.interviewerLibrary,
                ),
                _buildSidebarItem(
                  icon: Icons.local_library_outlined,
                  label: 'Practice Library',
                  route: FitCheckRoute.practiceLibrary,
                ),
                _buildSidebarItem(
                  icon: Icons.map_outlined,
                  label: 'Learning Plan',
                  route: FitCheckRoute.learningPlan,
                ),

                const SizedBox(height: 8),
                _buildSectionHeader('INTERVIEWS'),
                _buildSidebarItem(
                  icon: Icons.history,
                  label: 'Interview History',
                  route: FitCheckRoute.history,
                ),

                const SizedBox(height: 8),
                _buildSectionHeader('PROGRESS'),
                _buildSidebarItem(
                  icon: Icons.trending_up,
                  label: 'Skill Analytics',
                  route: FitCheckRoute.skillAnalytics,
                ),

                const SizedBox(height: 8),
                _buildSectionHeader('PERSONAL & SUPPORT'),
                _buildSidebarItem(
                  icon: Icons.person_outline,
                  label: 'Candidate Profile',
                  route: FitCheckRoute.candidateProfile,
                ),
                _buildSidebarItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  route: FitCheckRoute.notifications,
                ),
                _buildSidebarItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  route: FitCheckRoute.settings,
                ),
                _buildSidebarItem(
                  icon: Icons.help_outline,
                  label: 'Help & FAQ',
                  route: FitCheckRoute.helpFaq,
                ),
              ],
            ),
          ),

          // Candidate Footer Tile with Sign Out
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: FitCheckTheme.surfaceContainerHighest,
                  child: Text(
                    (candidate?.fullName.isNotEmpty == true
                            ? candidate!.fullName[0]
                            : (currentUser?.displayName?.isNotEmpty == true
                                ? currentUser!.displayName![0]
                                : 'C'))
                        .toUpperCase(),
                    style: const TextStyle(
                      color: FitCheckTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate?.fullName ?? currentUser?.displayName ?? 'Candidate',
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentUser?.email ?? 'candidate@fitcheck.io',
                        style: FitCheckTheme.labelSmall(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('sidebar_sign_out_button'),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: FitCheckTheme.outline),
                  tooltip: 'Sign Out',
                  onPressed: onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 10, bottom: 4),
      child: Text(
        title,
        style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 10),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required FitCheckRoute route,
  }) {
    final isSelected = currentRoute == route;
    return InkWell(
      key: Key('sidebar_nav_${route.name}'),
      onTap: () => onNavigate(route),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? FitCheckTheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: FitCheckTheme.bodySmall(
                  color: isSelected ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant,
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
