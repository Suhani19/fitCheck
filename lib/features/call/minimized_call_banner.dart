import 'package:flutter/material.dart';

import '../../core/theme/fitcheck_theme.dart';
import 'call_session_manager.dart';

class MinimizedCallBanner extends StatelessWidget {
  const MinimizedCallBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CallSessionManager.instance,
      builder: (context, _) {
        final manager = CallSessionManager.instance;
        if (!manager.isCallActive || !manager.isMinimized) {
          return const SizedBox.shrink();
        }

        final interviewer = manager.activeInterviewer;
        final charName = interviewer?.name ?? 'Interviewer';
        final initial = charName.isNotEmpty ? charName[0].toUpperCase() : 'I';
        final difficulty = manager.activeDifficulty;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => manager.restore(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: manager.interviewerSpeaking
                          ? FitCheckTheme.tertiary.withValues(alpha: 0.8)
                          : FitCheckTheme.outlineVariant,
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with speaking dot
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: FitCheckTheme.primaryGradient,
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: FitCheckTheme.surfaceContainerHighest,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: FitCheckTheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: manager.interviewerSpeaking
                                    ? FitCheckTheme.tertiary
                                    : FitCheckTheme.outline,
                                border: Border.all(
                                  color: FitCheckTheme.surfaceContainerLowest,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charName,
                              style: TextStyle(
                                color: FitCheckTheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (difficulty != null && difficulty.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: FitCheckTheme.difficultyColor(difficulty).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      difficulty.toUpperCase(),
                                      style: TextStyle(
                                        color: FitCheckTheme.difficultyColor(difficulty),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: manager.interviewerSpeaking
                                        ? FitCheckTheme.tertiary
                                        : FitCheckTheme.outline,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Interview in progress • ${manager.formattedCallTime}',
                                    style: TextStyle(
                                      color: FitCheckTheme.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Return action
                      OutlinedButton.icon(
                        onPressed: () => manager.restore(context),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 14),
                        label: const Text(
                          'Return',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FitCheckTheme.primary,
                          side: const BorderSide(
                            color: FitCheckTheme.outlineVariant,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // End call button
                      IconButton(
                        onPressed: () => manager.endCall(),
                        style: IconButton.styleFrom(
                          backgroundColor: FitCheckTheme.errorContainer,
                          foregroundColor: FitCheckTheme.error,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                        icon: const Icon(Icons.call_end, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
