import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class HelpFaqPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const HelpFaqPage({
    super.key,
    this.candidate,
    this.currentUser,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  final List<Map<String, String>> _faqs = [
    {
      'q': 'Why is the "Test Chime" button required in Hardware Readiness?',
      'a': 'Modern browsers enforce strict autoplay policies that block audio playback until the user performs a direct physical gesture. Clicking "Test Chime" unlocks browser audio context and confirms that your speakers/headphones are functioning before entering the live WebRTC room.',
    },
    {
      'q': 'How does FitCheck capture my microphone audio level?',
      'a': 'FitCheck utilizes native browser MediaStream APIs to capture your microphone with WebM Opus encoding and decibel normalization (dBFS). The equalizer reflects your live vocal intensity rather than simulated animations.',
    },
    {
      'q': 'How is the Evaluation Scorecard generated?',
      'a': 'During your simulation, transcript turns and conversational latencies are streamed to the backend evaluation engine. The evaluator scores your responses against Level 6/Staff engineering rubrics (such as Raft consensus, fault tolerance, and trade-off articulation).',
    },
    {
      'q': 'Where can I review my previous interview transcripts?',
      'a': 'Navigate to "Interview History" in the sidebar. Every persisted interview record links directly to its completed scorecard, transcript turn log, and architectural gap analysis.',
    },
    {
      'q': 'Can I retake a practice scenario or simulation?',
      'a': 'Yes. You can retake any simulation from either the Practice Library or the bottom action bar on an existing Evaluation Scorecard. Retakes generate fresh session IDs and isolated evaluations.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.helpFaq,
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
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(isDesktop),
                          const SizedBox(height: 24),
                          ..._faqs.map((f) => _buildFaqTile(f)),
                          const SizedBox(height: 32),
                          _buildSupportCard(),
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
              Text('SUPPORT', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Help & Documentation', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Frequently Asked Questions', style: FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Everything you need to know about browser audio, interview evaluations, and simulation scoring.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildFaqTile(Map<String, String> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          faq['q']!,
          style: FitCheckTheme.titleMedium().copyWith(fontSize: 14),
        ),
        iconColor: FitCheckTheme.primary,
        collapsedIconColor: FitCheckTheme.outline,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            faq['a']!,
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset_mic_outlined, size: 32, color: FitCheckTheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Encountering audio issues?', style: FitCheckTheme.titleMedium()),
                const SizedBox(height: 4),
                Text(
                  'Make sure your browser permits microphone access and hardware acceleration is enabled.',
                  style: FitCheckTheme.bodySmall(),
                ),
              ],
            ),
          ),
          OutlinedButton(
            key: const Key('help_hardware_test_btn'),
            onPressed: () => widget.onNavigate(FitCheckRoute.hardwareSetup),
            style: OutlinedButton.styleFrom(
              foregroundColor: FitCheckTheme.primary,
              side: const BorderSide(color: FitCheckTheme.primary),
            ),
            child: const Text('Test Hardware'),
          ),
        ],
      ),
    );
  }
}
