import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class AppSettingsPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final FitCheckApiService? apiService;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const AppSettingsPage({
    super.key,
    this.candidate,
    this.currentUser,
    this.apiService,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  bool _echoCancellation = true;
  bool _autoChime = false;
  bool _liveTurnStreaming = true;
  bool _highContrast = false;
  static const String _audioCodec = 'Opus (Native / Web)';

  List<FitCheckCandidateMemory> _memories = [];
  bool _loadingMemories = true;
  String? _memoriesError;
  bool _clearingMemories = false;

  FitCheckApiService get _effectiveApiService => widget.apiService ?? FitCheckApiService();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchMemories();
  }

  Future<void> _fetchMemories() async {
    setState(() {
      _loadingMemories = true;
      _memoriesError = null;
    });
    try {
      final list = await _effectiveApiService.getCandidateMemories();
      if (!mounted) return;
      setState(() {
        _memories = list;
        _loadingMemories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMemories = false;
        _memoriesError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _deleteMemory(FitCheckCandidateMemory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitCheckTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Delete Practice Memory?'),
        content: Text(
          'This will permanently remove this insight ("${memory.content}") from your longitudinal practice context.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: FitCheckTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FitCheckTheme.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _effectiveApiService.deleteCandidateMemory(memory.id);
      if (!mounted) return;
      setState(() {
        _memories.removeWhere((m) => m.id == memory.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory record deleted from candidate practice context.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete memory: $e'),
          backgroundColor: FitCheckTheme.error,
        ),
      );
    }
  }

  Future<void> _clearAllMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitCheckTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: FitCheckTheme.error, size: 20),
            SizedBox(width: 8),
            Text('Purge All Practice Memories?'),
          ],
        ),
        content: const Text(
          'This permanently deletes all technical strengths, identified gaps, and project facts extracted across all your simulation interviews. Future interviews will start with a fresh practice baseline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: FitCheckTheme.outline)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: FitCheckTheme.error),
            child: const Text('Purge All Memories', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearingMemories = true);
    try {
      final count = await _effectiveApiService.clearCandidateMemories();
      if (!mounted) return;
      setState(() {
        _memories.clear();
        _clearingMemories = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purged $count candidate practice memories successfully.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _clearingMemories = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to purge memories: $e'),
          backgroundColor: FitCheckTheme.error,
        ),
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _echoCancellation = prefs.getBool('pref_echo_cancellation') ?? true;
      _autoChime = prefs.getBool('pref_auto_chime') ?? false;
      _liveTurnStreaming = prefs.getBool('pref_live_turn_streaming') ?? true;
      _highContrast = prefs.getBool('pref_high_contrast') ?? false;
    });
  }

  Future<void> _setPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

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
              currentRoute: FitCheckRoute.settings,
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
                          _buildAudioSettingsCard(),
                          const SizedBox(height: 20),
                          _buildSimulationSettingsCard(),
                          const SizedBox(height: 20),
                          _buildCandidateMemoryCard(),
                          const SizedBox(height: 20),
                          _buildAccountCard(),
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
              Text('SETTINGS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Hardware & Simulation Calibration', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
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
        Text('Preferences & System Settings', style: FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Fine-tune browser audio buffers, simulation telemetry, and account session controls.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildAudioSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUDIO & WEBRTC ENGINE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 16),
          _buildSwitchRow(
            title: 'Acoustic Echo Cancellation (AEC)',
            subtitle: 'Recommended when using laptop speakers without headphones.',
            value: _echoCancellation,
            onChanged: (v) {
              setState(() => _echoCancellation = v);
              _setPreference('pref_echo_cancellation', v);
            },
          ),
          const Divider(height: 24, color: FitCheckTheme.outlineVariant),
          _buildSwitchRow(
            title: 'Auto-Test Chime On Setup Entry',
            subtitle: 'Automatically plays chime once user interacts with setup screen.',
            value: _autoChime,
            onChanged: (v) {
              setState(() => _autoChime = v);
              _setPreference('pref_auto_chime', v);
            },
          ),
          const Divider(height: 24, color: FitCheckTheme.outlineVariant),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio Capture Codec', style: FitCheckTheme.titleMedium().copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Browser-supported recording codec for metering.', style: FitCheckTheme.bodySmall()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_audioCodec, style: const TextStyle(fontSize: 12, color: FitCheckTheme.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SIMULATION & EVALUATION', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
          const SizedBox(height: 16),
          _buildSwitchRow(
            title: 'Real-Time Turn Streaming',
            subtitle: 'Stream transcript turns synchronously to the backend during live interview.',
            value: _liveTurnStreaming,
            onChanged: (v) {
              setState(() => _liveTurnStreaming = v);
              _setPreference('pref_live_turn_streaming', v);
            },
          ),
          const Divider(height: 24, color: FitCheckTheme.outlineVariant),
          _buildSwitchRow(
            title: 'High-Contrast Decibel Waveforms',
            subtitle: 'Enhance visual dynamic range of the 36-band equalizer.',
            value: _highContrast,
            onChanged: (v) {
              setState(() => _highContrast = v);
              _setPreference('pref_high_contrast', v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateMemoryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
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
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, color: FitCheckTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CANDIDATE PRACTICE MEMORY & PRIVACY',
                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_memories.isNotEmpty)
                TextButton.icon(
                  key: const Key('clear_all_memories_btn'),
                  onPressed: _clearingMemories ? null : _clearAllMemories,
                  icon: _clearingMemories
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.error))
                      : const Icon(Icons.delete_sweep_outlined, size: 16, color: FitCheckTheme.error),
                  label: const Text('Purge All Memories', style: TextStyle(color: FitCheckTheme.error, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'FitCheck retains durable technical milestones, demonstrated strengths, and identified growth areas across your practice sessions. Socratic interviewers leverage this memory to challenge recurring weak spots and measure longitudinal improvement. Raw audio streams and personal credentials are never stored.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          const Divider(color: FitCheckTheme.outlineVariant),
          const SizedBox(height: 16),
          if (_loadingMemories)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: FitCheckTheme.primary),
              ),
            )
          else if (_memoriesError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitCheckTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: FitCheckTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_memoriesError!, style: const TextStyle(color: FitCheckTheme.error, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: _fetchMemories,
                    child: const Text('Retry', style: TextStyle(color: FitCheckTheme.primary, fontSize: 12)),
                  ),
                ],
              ),
            )
          else if (_memories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.memory, size: 32, color: FitCheckTheme.outline),
                  const SizedBox(height: 8),
                  Text(
                    'No practice memories recorded yet',
                    style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete an interview simulation to establish your baseline practice memory.',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _memories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final mem = _memories[index];
                final categoryColor = _getCategoryColor(mem.category);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          mem.category.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mem.content,
                              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                            ),
                            if (mem.createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Recorded: ${mem.createdAt!.split('T').first}',
                                style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 10),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: Key('delete_memory_btn_${mem.id}'),
                        icon: const Icon(Icons.delete_outline, size: 16, color: FitCheckTheme.outline),
                        hoverColor: FitCheckTheme.error.withValues(alpha: 0.1),
                        tooltip: 'Delete practice memory',
                        onPressed: () => _deleteMemory(mem),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'technical_fact':
      case 'fact':
        return FitCheckTheme.primary;
      case 'strength':
      case 'mastery':
        return FitCheckTheme.tertiary;
      case 'weakness':
      case 'gap':
      case 'growth_area':
        return FitCheckTheme.secondary;
      default:
        return FitCheckTheme.outline;
    }
  }

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SESSION & ACCOUNT', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Candidate Sign Out', style: FitCheckTheme.titleMedium().copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('End active authentication session and return to public portal.', style: FitCheckTheme.bodySmall()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('settings_sign_out_btn'),
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout, size: 14, color: FitCheckTheme.error),
                label: const Text('Sign Out', style: TextStyle(color: FitCheckTheme.error, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: FitCheckTheme.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: FitCheckTheme.titleMedium().copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: FitCheckTheme.bodySmall()),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: FitCheckTheme.primary,
        ),
      ],
    );
  }
}
