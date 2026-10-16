import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class InterviewerSelectionPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final Function(FitCheckInterviewer interviewer) onInterviewerSelected;

  const InterviewerSelectionPage({
    super.key,
    required this.apiService,
    required this.onInterviewerSelected,
  });

  @override
  State<InterviewerSelectionPage> createState() => _InterviewerSelectionPageState();
}

class _InterviewerSelectionPageState extends State<InterviewerSelectionPage> {
  List<FitCheckInterviewer> _interviewers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInterviewers();
  }

  Future<void> _fetchInterviewers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.listInterviewers();
      if (!mounted) return;
      setState(() {
        _interviewers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
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
        title: const Text('Select Interviewer Persona', style: TextStyle(color: FitCheckTheme.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FitCheckTheme.primary))
          : SingleChildScrollView(
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

                  const Text(
                    'Choose an Interviewer Persona',
                    style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Built-in presets embody verified engineering backgrounds, distinct questioning styles, and voices.',
                    style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  ..._interviewers.map((interviewer) {
                    return Card(
                      color: FitCheckTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: FitCheckTheme.borderSubtle),
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: FitCheckTheme.surfaceElevated,
                                  child: Text(
                                    interviewer.name.isNotEmpty ? interviewer.name[0] : 'I',
                                    style: const TextStyle(color: FitCheckTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        interviewer.name,
                                        style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        interviewer.title,
                                        style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: FitCheckTheme.surfaceElevated,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: FitCheckTheme.border),
                                  ),
                                  child: Text(
                                    interviewer.questioningStyle.toUpperCase(),
                                    style: const TextStyle(color: FitCheckTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (interviewer.bio != null && interviewer.bio!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                interviewer.bio!,
                                style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.record_voice_over_outlined, size: 16, color: FitCheckTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Voice: ${interviewer.voiceId}',
                                      style: const TextStyle(color: FitCheckTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () => widget.onInterviewerSelected(interviewer),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FitCheckTheme.primary,
                                    foregroundColor: FitCheckTheme.background,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  child: const Text('Select', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

