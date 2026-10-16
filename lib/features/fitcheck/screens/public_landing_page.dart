import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/fitcheck_theme.dart';

class PublicLandingPage extends StatefulWidget {
  final VoidCallback onStartPreparing;
  final VoidCallback onSignIn;

  const PublicLandingPage({
    super.key,
    required this.onStartPreparing,
    required this.onSignIn,
  });

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _platformKey = GlobalKey();
  final GlobalKey _personasKey = GlobalKey();
  final GlobalKey _voiceStudioKey = GlobalKey();
  final GlobalKey _evaluationsKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();

  int _selectedPersonaTab = 0;

  final List<String> _personaTabs = [
    'Marcus Vance (Distributed Systems)',
    'Sarah Chen (EM & Infra Architecture)',
    'Alex Rivera (Product Scale)',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final currentContext = key.currentContext;
    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 992;

    return Scaffold(
      backgroundColor: FitCheckTheme.surfaceCanvas,
      body: Column(
        children: [
          _buildTopNav(isDesktop),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  _buildHeroSection(isDesktop),
                  _buildTelemetryStrip(isDesktop),
                  Container(key: _platformKey, child: _buildPlatformSection(isDesktop)),
                  Container(key: _personasKey, child: _buildPersonaShowcase(isDesktop)),
                  Container(key: _voiceStudioKey, child: _buildVoiceStudioSection(isDesktop)),
                  Container(key: _evaluationsKey, child: _buildEvaluationsSection(isDesktop)),
                  Container(key: _pricingKey, child: _buildPricingSection(isDesktop)),
                  _buildPreparationFlywheel(isDesktop),
                  _buildCandidateTestimonials(isDesktop),
                  _buildBottomCta(isDesktop),
                  _buildFooter(isDesktop),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav(bool isDesktop) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLowest.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo
          InkWell(
            onTap: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(width: 2, height: 8, color: FitCheckTheme.primary),
                        const SizedBox(width: 2),
                        Container(width: 2, height: 16, color: FitCheckTheme.primary),
                        const SizedBox(width: 2),
                        Container(width: 2, height: 12, color: FitCheckTheme.secondary),
                        const SizedBox(width: 2),
                        Container(width: 2, height: 8, color: FitCheckTheme.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'FitCheck',
                          style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface)
                              .copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: FitCheckTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'GET FIT. CHECK FIT.',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)
                          .copyWith(fontSize: 9, letterSpacing: 1.2),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nav Items
          if (isDesktop)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _navItem('Platform', () => _scrollToSection(_platformKey)),
                    _navItem('Interviewer Personas', () => _scrollToSection(_personasKey)),
                    _navItem('Voice Studio', () => _scrollToSection(_voiceStudioKey)),
                    _navItem('Evaluations', () => _scrollToSection(_evaluationsKey)),
                    _navItem('Pricing', () => _scrollToSection(_pricingKey)),
                  ],
                ),
              ),
            ),

          // CTA Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const Key('landing_sign_in_btn'),
                onPressed: widget.onSignIn,
                child: Text(
                  'Sign In',
                  style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('landing_get_started_btn'),
                onPressed: widget.onStartPreparing,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Start Preparing Free'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: FitCheckTheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant)
                .copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48 : 20,
        vertical: isDesktop ? 56 : 32,
      ),
      child: Column(
        children: [
          // Eyebrow Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: FitCheckTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'OVERFIT LABS • FITCHECK 2.0 • ULTRA-LOW LATENCY VOICE AI',
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface)
                      .copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main Headline
          Text(
            "Your next interview shouldn't be a surprise.",
            textAlign: TextAlign.center,
            style: isDesktop
                ? FitCheckTheme.displayLarge().copyWith(fontSize: 48, height: 1.15)
                : FitCheckTheme.headlineXLarge().copyWith(fontSize: 30),
          ),
          const SizedBox(height: 16),

          // Subheadline
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              'Practice with AI interviewers who adapt to your answers, challenge your architectural reasoning, and pressure-test you for the role you actually want.',
              textAlign: TextAlign.center,
              style: FitCheckTheme.bodyLarge(color: FitCheckTheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),

          // CTAs
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('hero_start_preparing_btn'),
                onPressed: widget.onStartPreparing,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Start Preparing Free'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: FitCheckTheme.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('hero_live_flightdeck_btn'),
                onPressed: widget.onStartPreparing,
                icon: const Icon(Icons.play_circle_fill, size: 18, color: FitCheckTheme.primary),
                label: const Text('Live Simulation Flightdeck'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.onSurface,
                  backgroundColor: FitCheckTheme.surfaceContainerHigh,
                  side: const BorderSide(color: FitCheckTheme.outlineVariant),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: FitCheckTheme.bodyLarge(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Trust Badges
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _badgeDot(FitCheckTheme.tertiary, 'No credit card required'),
              const Text('•', style: TextStyle(color: FitCheckTheme.outline)),
              _badgeDot(FitCheckTheme.primary, 'Realistic voice synthesis'),
              const Text('•', style: TextStyle(color: FitCheckTheme.outline)),
              _badgeDot(FitCheckTheme.secondary, '48kHz audio telemetry'),
            ],
          ),
          const SizedBox(height: 48),

          // Hero Interactive Preview Card
          _buildHeroPreviewCard(isDesktop),
        ],
      ),
    );
  }

  Widget _badgeDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildHeroPreviewCard(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1040),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FitCheckTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: FitCheckTheme.primary.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Console status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: FitCheckTheme.error, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE SIMULATION IN PROGRESS',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text('/', style: TextStyle(color: FitCheckTheme.outline.withValues(alpha: 0.5))),
                    const SizedBox(width: 8),
                    Text('Staff Systems Engineer @ Stripe', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.tertiary, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('24ms AUDIO LATENCY', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('00:34:18 / 45:00', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),

          // Persona Tabs
          Container(
            color: FitCheckTheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_personaTabs.length, (idx) {
                  final isSelected = _selectedPersonaTab == idx;
                  return InkWell(
                    onTap: () => setState(() => _selectedPersonaTab = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? FitCheckTheme.surfaceContainerLowest : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _personaTabs[idx],
                            style: FitCheckTheme.labelSmall(
                              color: isSelected ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildInterviewerLeftPanel()),
                      const SizedBox(width: 20),
                      Expanded(flex: 7, child: _buildTranscriptRightPanel()),
                    ],
                  )
                : Column(
                    children: [
                      _buildInterviewerLeftPanel(),
                      const SizedBox(height: 20),
                      _buildTranscriptRightPanel(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterviewerLeftPanel() {
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.5)),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: FitCheckTheme.primary, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Marcus Vance',
                            style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: FitCheckTheme.primary, size: 14),
                      ],
                    ),
                    Text(
                      'Principal Distributed Systems Architect',
                      style: FitCheckTheme.bodySmall(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Style: Socratic • High Pressure • Metric-Obsessed',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waveform
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: FitCheckTheme.primary, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'INTERVIEWER SPEAKING',
                              style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('-16.8 dBFS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (i) {
                      final h = 8.0 + (sin(i * 0.5 + _animController.value * pi * 2).abs() * 24.0);
                      final isCyan = i % 3 != 0;
                      return Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: isCyan ? FitCheckTheme.primary : FitCheckTheme.secondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptRightPanel() {
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
              Text('ACTIVE QUESTION // 03', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
              Text('142 WPM Pacing', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“Walk me through your partition strategy when an AZ completely severs network connectivity. How does your shard leader detect consensus failure before split-braining?”',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: FitCheckTheme.tertiary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Candidate response: "We enforce bounded lease-heartbeats and multi-raft quorums. Leaders automatically fail-fast after 350ms of heartbeat silence."',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryStrip(bool isDesktop) {
    final stats = [
      {'label': 'AUDIO LATENCY', 'val': '24ms', 'sub': 'Sub-second real-time streaming'},
      {'label': 'PRACTICE DRILLS', 'val': '14+', 'sub': 'Targeted domain scenarios'},
      {'label': 'SIMULATION REALISM', 'val': '98%', 'sub': 'Calibrated against FAANG bar'},
      {'label': 'PACING TELEMETRY', 'val': '48kHz', 'sub': 'Lossless cadence analysis'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 32),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.35 : 1.15,
        ),
        itemCount: stats.length,
        itemBuilder: (context, i) {
          final s = stats[i];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s['label']!, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                const SizedBox(height: 4),
                Text(s['val']!, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.primary)),
                Text(s['sub']!, style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlatformSection(bool isDesktop) {
    final pillars = [
      {
        'num': '01',
        'title': 'Socratic AI Interviewers',
        'desc': 'Interactive personas who challenge edge cases, probe architectural fallacies, and mirror strict hiring committees.',
        'icon': Icons.psychology_outlined,
      },
      {
        'num': '02',
        'title': 'Deep Competency Rubrics',
        'desc': 'Automated L5-L7 evaluation criteria across system trade-offs, fault tolerance, and communication composure.',
        'icon': Icons.analytics_outlined,
      },
      {
        'num': '03',
        'title': 'High-Fidelity Audio Telemetry',
        'desc': 'Real-time speech pacing, filler word detection, decibel stability, and interruption recovery analysis.',
        'icon': Icons.graphic_eq_outlined,
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENGINEERED FOR HIGH-STAKES INTERVIEWS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 6),
          Text('Don\'t simulate an interview. Simulate THEIR interview.', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 12),
          Text(
            'A generic chatbot telling you "good job" won\'t prepare you for an aggressive Principal Architect picking apart your consensus protocol. FitCheck replicates the exact cognitive pressure of top hiring loops.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          isDesktop
              ? Row(
                  children: pillars.map((p) => Expanded(child: _pillarCard(p))).toList(),
                )
              : Column(
                  children: pillars.map((p) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _pillarCard(p))).toList(),
                ),
        ],
      ),
    );
  }

  Widget _pillarCard(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
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
              Text(p['num'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
              Icon(p['icon'] as IconData, color: FitCheckTheme.outline, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(p['title'] as String, style: FitCheckTheme.headlineMedium(color: FitCheckTheme.onSurface).copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(p['desc'] as String, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildPersonaShowcase(bool isDesktop) {
    final personas = [
      {
        'name': 'Marcus Vance',
        'title': 'Principal Distributed Systems Architect',
        'role': 'Calibrated to Meta / Stripe E7',
        'style': 'Socratic, metric-driven, interrupt-heavy.',
        'focus': 'CAP theorem tradeoffs, Paxos/Raft consensus, cache stampedes, p99 tail latencies.',
        'provocation': '“Your database can\'t absorb that write fanout during an unannounced flash sale. Where does the spillover queue sit?”',
        'badge': 'DISTRIBUTED SYSTEMS',
        'color': FitCheckTheme.primary,
        'voice': 'US-Pacific / Male / Tenor',
      },
      {
        'name': 'Sarah Chen',
        'title': 'VP of Infrastructure Engineering',
        'role': 'Calibrated to Google / Datadog L8',
        'style': 'Rigorous, structured, behavioral-technical crossover.',
        'focus': 'Incident postmortems, cross-org friction, budget trade-offs, engineering morale under outages.',
        'provocation': '“You have two Staff Engineers with diametrically opposed designs for migration, and downtime is escalating. How do you resolve this within 48 hours?”',
        'badge': 'ENG LEADERSHIP & OPS',
        'color': FitCheckTheme.secondary,
        'voice': 'US-West / Female / Alto',
      },
      {
        'name': 'Alex Rivera',
        'title': 'Staff Full-Stack Product Engineer',
        'role': 'Calibrated to Airbnb / Figma L6',
        'style': 'Pragmatic, collaborative, user-impact driven.',
        'focus': 'Real-time collaboration engines, client performance budgets, offline caching, API contracts.',
        'provocation': '“Your schema design is theoretically pure, but it doubles serialization costs on 3G cellular devices. What will you compromise to maintain 60 FPS?”',
        'badge': 'PRODUCT & SCALE',
        'color': FitCheckTheme.tertiary,
        'voice': 'US-Midwest / Non-Binary / Warm',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALIBRATED PERSONAS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
          const SizedBox(height: 6),
          Text('Meet Your Simulated Interviewers', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 8),
          Text(
            'Engineered to reflect specific seniority levels, communication tones, and uncompromising technical standards.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: personas.map((p) => Expanded(child: _personaCard(p))).toList(),
                )
              : Column(
                  children: personas.map((p) => Padding(padding: const EdgeInsets.only(bottom: 20), child: _personaCard(p))).toList(),
                ),
        ],
      ),
    );
  }

  Widget _personaCard(Map<String, dynamic> p) {
    final color = p['color'] as Color;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  p['badge'] as String,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
              const Icon(Icons.psychology, size: 18, color: FitCheckTheme.outline),
            ],
          ),
          const SizedBox(height: 14),
          Text(p['name'] as String, style: FitCheckTheme.headlineMedium().copyWith(fontSize: 18)),
          Text(p['title'] as String, style: FitCheckTheme.bodySmall(color: FitCheckTheme.primary)),
          Text(p['role'] as String, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const Divider(height: 20, color: FitCheckTheme.outlineVariant),
          Text('Style:', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface)),
          Text(p['style'] as String, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Core Focus:', style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurface)),
          Text(p['focus'] as String, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Text(
              p['provocation'] as String,
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.volume_up, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p['voice'] as String,
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: widget.onStartPreparing,
                child: Text('Spar Now →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceStudioSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STUDIO ACOUSTIC INTELLIGENCE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 6),
          Text('Built on an audio engine that feels frighteningly real.', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 8),
          Text(
            'Unlike generic LLM wrappers that force an unnatural push-to-talk rhythm, FitCheck operates with sub-second full-duplex audio stream analysis.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _studioFeature('Zero-Latency Turn Taking', 'Streaming WebRTC architecture eliminates the robotic "pause-and-think" delay. The interviewer responds immediately when you finish speaking.', Icons.speed, FitCheckTheme.primary)),
                    const SizedBox(width: 16),
                    Expanded(child: _studioFeature('Context-Aware Interruptions', 'If your explanation starts spiraling into generic filler, FitCheck cuts in to redirect you. Practice recovering gracefully from unexpected pivots.', Icons.front_hand, FitCheckTheme.secondary)),
                    const SizedBox(width: 16),
                    Expanded(child: _studioFeature('Acoustic Pacing & Composure', 'We monitor inflection shifts, pitch tension, and speech acceleration under aggressive cross-examination so you can train executive presence.', Icons.graphic_eq, FitCheckTheme.tertiary)),
                  ],
                )
              : Column(
                  children: [
                    _studioFeature('Zero-Latency Turn Taking', 'Streaming WebRTC architecture eliminates the robotic "pause-and-think" delay.', Icons.speed, FitCheckTheme.primary),
                    const SizedBox(height: 16),
                    _studioFeature('Context-Aware Interruptions', 'If your explanation starts spiraling into generic filler, FitCheck cuts in to redirect you.', Icons.front_hand, FitCheckTheme.secondary),
                    const SizedBox(height: 16),
                    _studioFeature('Acoustic Pacing & Composure', 'We monitor inflection shifts, pitch tension, and speech acceleration under aggressive cross-examination.', Icons.graphic_eq, FitCheckTheme.tertiary),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _studioFeature(String title, String desc, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(title, style: FitCheckTheme.headlineMedium().copyWith(fontSize: 16)),
          const SizedBox(height: 8),
          Text(desc, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEvaluationsSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POST-SESSION DEEP AUDIT', style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
          const SizedBox(height: 6),
          Text('Verbatim Rubric Auditing. No Generic Advice.', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 8),
          Text(
            'Instead of vague feedback like "be more concise," FitCheck matches your exact recorded words against calibrated hiring committee guidelines.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // Scorecard Preview Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text('Session Evaluation Scorecard', style: FitCheckTheme.headlineMedium().copyWith(fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('STAFF BAR: STRONG PASS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        Text('Role: Staff Infrastructure Engineer • Evaluated by Marcus Vance Model', style: FitCheckTheme.bodySmall()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 3 competencies
                isDesktop
                    ? Row(
                        children: [
                          Expanded(child: _rubricMeter('Distributed Consensus', '9.2 / 10', 0.92, FitCheckTheme.tertiary)),
                          const SizedBox(width: 16),
                          Expanded(child: _rubricMeter('Trade-Off Clarity', '8.8 / 10', 0.88, FitCheckTheme.primary)),
                          const SizedBox(width: 16),
                          Expanded(child: _rubricMeter('Interruption Recovery', '7.4 / 10', 0.74, FitCheckTheme.secondary)),
                        ],
                      )
                    : Column(
                        children: [
                          _rubricMeter('Distributed Consensus', '9.2 / 10', 0.92, FitCheckTheme.tertiary),
                          const SizedBox(height: 12),
                          _rubricMeter('Trade-Off Clarity', '8.8 / 10', 0.88, FitCheckTheme.primary),
                          const SizedBox(height: 12),
                          _rubricMeter('Interruption Recovery', '7.4 / 10', 0.74, FitCheckTheme.secondary),
                        ],
                      ),
                const SizedBox(height: 20),
                // Verbatim Quote Callout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('VERBATIM TRANSCRIPT AUDIT', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                          Text('00:22:14 In-Session', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'What you said: "...we could probably just toss an in-memory cache like Redis in front of PostgreSQL to absorb the burst spikes."',
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Calibrated Finding: Penalized for hand-waving cache invalidation and thundering herd risk under Redis restarts. A Staff candidate must address cache lease locks or probabilistic early expiration.',
                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rubricMeter(String name, String score, double pct, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(score, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: FitCheckTheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 56),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FitCheckTheme.outlineVariant),
            ),
            child: Text(
              'HONEST ACCESS & PLANS',
              style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)
                  .copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose How You Prepare',
            style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineLarge(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              'No hidden subscription traps or inflated credit claims. Clear distinctions between standard practice and upcoming studio capabilities.',
              style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),

          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildFreePricingCard()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildPayAsYouGoPricingCard()),
                  ],
                )
              : Column(
                  children: [
                    _buildFreePricingCard(),
                    const SizedBox(height: 24),
                    _buildPayAsYouGoPricingCard(),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildFreePricingCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('STANDARD ACCESS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.check_circle_outline, color: FitCheckTheme.tertiary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text('Free', style: FitCheckTheme.headlineXLarge().copyWith(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Core interview practice and standard candidate tools for serious technical preparation.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const Divider(height: 32, color: FitCheckTheme.outlineVariant),
          _pricingFeatureRow(Icons.check, 'Full access to candidate dashboard & command center', true),
          _pricingFeatureRow(Icons.check, 'Socratic voice interview simulations with preset interviewers', true),
          _pricingFeatureRow(Icons.check, 'Evidence-backed scorecard evaluations with rubric criteria', true),
          _pricingFeatureRow(Icons.check, 'Practice drill library across systems, storage, and concurrency', true),
          _pricingFeatureRow(Icons.check, 'Hardware readiness & audio telemetry diagnostics', true),
          const SizedBox(height: 12),
          Text('Current Limitations:', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 4),
          _pricingFeatureRow(Icons.remove, 'Single audio stream (voice-only interview room)', false),
          _pricingFeatureRow(Icons.remove, 'Standard persona roster (Marcus, Sarah, Alex)', false),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('free_tier_cta_btn'),
              onPressed: widget.onStartPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.surfaceContainerHigh,
                foregroundColor: FitCheckTheme.onSurface,
                side: const BorderSide(color: FitCheckTheme.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Start Preparing Free', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayAsYouGoPricingCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: FitCheckTheme.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FitCheckTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('EXPANDED CAPABILITIES', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.rocket_launch, color: FitCheckTheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text('Pay as you go', style: FitCheckTheme.headlineXLarge().copyWith(fontSize: 28, fontWeight: FontWeight.bold, color: FitCheckTheme.primary)),
          const SizedBox(height: 6),
          Text(
            'On-demand usage for advanced interview simulations, video calls, and multi-interviewer panels.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const Divider(height: 32, color: FitCheckTheme.outlineVariant),
          _pricingFeatureRow(Icons.check, 'Everything included in the Free tier', true),
          _pricingFeatureRow(Icons.videocam_outlined, 'Video interview calls [Planned / Roadmap]', true, badge: 'PLANNED'),
          _pricingFeatureRow(Icons.group_outlined, 'Multiple concurrent interviewer voices [Planned]', true, badge: 'PLANNED'),
          _pricingFeatureRow(Icons.record_voice_over_outlined, 'Exclusive multi-voice practice scenarios [Planned]', true, badge: 'PLANNED'),
          _pricingFeatureRow(Icons.auto_fix_high, 'Custom interviewer synthesis from company job specs', true),
          _pricingFeatureRow(Icons.bolt, 'Priority ultra-low latency streaming voice infrastructure', true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: FitCheckTheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Private Preview: Planned premium features are currently in engineering testing. No billing required to get started.',
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('payg_tier_cta_btn'),
              onPressed: widget.onStartPreparing,
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.primary,
                foregroundColor: FitCheckTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: const Text('Explore Pay As You Go', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricingFeatureRow(IconData icon, String text, bool enabled, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: enabled ? FitCheckTheme.primary : FitCheckTheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: FitCheckTheme.bodySmall(
                      color: enabled ? FitCheckTheme.onSurface : FitCheckTheme.outline,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: FitCheckTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(badge, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: FitCheckTheme.secondary)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationFlywheel(bool isDesktop) {
    final steps = [
      {'num': '01', 'title': 'Target Spec Sync', 'desc': 'Paste your target job spec, level (L5/L6/L7), and stack. FitCheck sets calibrated rubric weightings.'},
      {'num': '02', 'title': 'Select Persona & Pressure', 'desc': 'Choose an interviewer archetype and set challenge pressure: Lenient, Realistic, or Stress Mode.'},
      {'num': '03', 'title': 'Run Live 45m Voice Loop', 'desc': 'Experience unscripted follow-up probes, architecture defense, and real-time counter-arguments.'},
      {'num': '04', 'title': 'Targeted Rubric Drills', 'desc': 'Review line-by-line quote feedback, then launch micro-drills to permanently fix detected blind spots.'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE PREPARATION FLYWHEEL', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 6),
          Text('From Target Role to Offer', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 24),
          isDesktop
              ? Row(
                  children: steps.map((s) => Expanded(child: _stepCard(s))).toList(),
                )
              : Column(
                  children: steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _stepCard(s))).toList(),
                ),
        ],
      ),
    );
  }

  Widget _stepCard(Map<String, String> s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s['num']!, style: FitCheckTheme.metricDisplay(color: FitCheckTheme.primary).copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(s['title']!, style: FitCheckTheme.headlineMedium().copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(s['desc']!, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCandidateTestimonials(bool isDesktop) {
    final reviews = [
      {
        'quote': '“Marcus Vance was more aggressive than my actual Stripe interviewers. When I got to the onsite, the Staff consensus questions felt like a familiar replay. Got the L6 offer with top-band equity.”',
        'author': 'David K.',
        'role': 'Staff Systems Engineer, Stripe',
      },
      {
        'quote': '“FitCheck diagnosed that I spoke at 178 WPM when challenged, which made me sound defensive. Three sessions with Sarah Chen leveled up my executive composure completely.”',
        'author': 'Priya M.',
        'role': 'Director of Eng, Datadog',
      },
      {
        'quote': '“The verbatim transcript breakdown is lethal. Seeing the exact sentence where my explanation of distributed locking became ambiguous changed my entire framework for systems rounds.”',
        'author': 'Liam S.',
        'role': 'Principal Architect, Snowflake',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 48),
      constraints: const BoxConstraints(maxWidth: 1040),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CANDIDATE PROOF', style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary)),
          const SizedBox(height: 6),
          Text('Calibrated Under Pressure. Hired at Top Tier.', style: FitCheckTheme.headlineLarge()),
          const SizedBox(height: 24),
          isDesktop
              ? Row(
                  children: reviews.map((r) => Expanded(child: _testimonialCard(r))).toList(),
                )
              : Column(
                  children: reviews.map((r) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _testimonialCard(r))).toList(),
                ),
        ],
      ),
    );
  }

  Widget _testimonialCard(Map<String, String> r) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r['quote']!, style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Text(r['author']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: FitCheckTheme.onSurface)),
          Text(r['role']!, style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildBottomCta(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 32),
      padding: const EdgeInsets.all(36),
      constraints: const BoxConstraints(maxWidth: 1040),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Ready to test your edge?',
            style: FitCheckTheme.headlineLarge(color: FitCheckTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Step into the studio and experience a realistic FAANG-level simulation.',
            style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const Key('bottom_cta_launch_btn'),
            onPressed: widget.onStartPreparing,
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Launch FitCheck Flightdeck'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: FitCheckTheme.outlineVariant, width: 0.8)),
      ),
      child: Center(
        child: Text(
          '© 2026 Overfit Labs • FitCheck AI Interview Simulation Platform',
          style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
        ),
      ),
    );
  }
}
