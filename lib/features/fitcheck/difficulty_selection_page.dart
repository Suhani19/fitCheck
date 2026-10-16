import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class DifficultyAndPreparationPage extends StatefulWidget {
  final FitCheckCandidate candidate;
  final FitCheckJob job;
  final FitCheckInterviewer interviewer;
  final FitCheckApiService apiService;
  final Function(FitCheckSession session) onSessionLaunched;

  const DifficultyAndPreparationPage({
    super.key,
    required this.candidate,
    required this.job,
    required this.interviewer,
    required this.apiService,
    required this.onSessionLaunched,
  });

  @override
  State<DifficultyAndPreparationPage> createState() => _DifficultyAndPreparationPageState();
}

class _DifficultyAndPreparationPageState extends State<DifficultyAndPreparationPage> {
  String _selectedDifficulty = 'realistic';
  bool _starting = false;
  String? _error;

  final Map<String, Map<String, String>> _difficultyDescriptions = {
    'lenient': {
      'title': 'Lenient Mode',
      'tagline': 'Supportive & Encouraging',
      'description': 'Friendly pacing, generous hints when requested, gentle clarification prompts, and foundational criteria.',
    },
    'realistic': {
      'title': 'Realistic Mode',
      'tagline': 'Standard Industry Hiring Bar',
      'description': 'Balanced 1-2 layer probing into technical trade-offs and rationale. Hints provided only when directly asked.',
    },
    'challenging': {
      'title': 'Challenging Mode',
      'tagline': 'Rigorous & Probing',
      'description': 'Deep probing into design decisions, edge cases, zero unsolicited hints, and scrutiny of failure mitigation.',
    },
    'expert_stress': {
      'title': 'Expert / Stress Mode',
      'tagline': 'High Intensity & Edge Cases',
      'description': 'Pressure-testing architecture with cascading failures and competing constraints while remaining strictly professional.',
    },
  };

  Future<void> _startInterview() async {
    setState(() {
      _starting = true;
      _error = null;
    });

    try {
      final session = await widget.apiService.startSession(
        candidateId: widget.candidate.id,
        jobId: widget.job.id,
        interviewerId: widget.interviewer.id,
        difficulty: _selectedDifficulty,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      widget.onSessionLaunched(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitCheckTheme.background,
      appBar: AppBar(
        backgroundColor: FitCheckTheme.surface,
        elevation: 0,
        title: const Text('Difficulty & Pre-Session Setup', style: TextStyle(color: FitCheckTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: FitCheckTheme.error)),
              ),
              const SizedBox(height: 16),
            ],

            // Context Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FitCheckTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interview Configuration', style: TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildContextRow(Icons.person_outline, 'Candidate', widget.candidate.fullName),
                  const SizedBox(height: 8),
                  _buildContextRow(Icons.work_outline, 'Target Role', '${widget.job.title} (${widget.job.seniority})'),
                  const SizedBox(height: 8),
                  _buildContextRow(Icons.record_voice_over_outlined, 'Interviewer', '${widget.interviewer.name} (${widget.interviewer.questioningStyle})'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Simulation Difficulty',
              style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Difficulty dynamically shapes question depth, follow-up intensity, and hint policy.',
              style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // 4 Difficulty Mode Cards
            ..._difficultyDescriptions.entries.map((entry) {
              final key = entry.key;
              final data = entry.value;
              final isSelected = _selectedDifficulty == key;
              final accentColor = FitCheckTheme.difficultyColor(key);

              return GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = key),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? FitCheckTheme.surfaceElevated : FitCheckTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? accentColor : FitCheckTheme.borderSubtle,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? accentColor : FitCheckTheme.textMuted, width: 2),
                          color: isSelected ? accentColor : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: FitCheckTheme.background)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  data['title']!,
                                  style: TextStyle(color: isSelected ? accentColor : FitCheckTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    data['tagline']!,
                                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['description']!,
                              style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Start Interview Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _starting ? null : _startInterview,
                icon: _starting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.background))
                    : const Icon(Icons.phone_in_talk_rounded),
                label: Text(
                  _starting ? 'Synthesizing Session Plan...' : 'Begin Real-Time Voice Interview',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: FitCheckTheme.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: FitCheckTheme.textMuted, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
