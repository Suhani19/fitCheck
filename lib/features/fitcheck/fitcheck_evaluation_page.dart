import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class FitCheckEvaluationReportPage extends StatefulWidget {
  final String sessionId;
  final FitCheckApiService apiService;
  final VoidCallback onDone;

  const FitCheckEvaluationReportPage({
    super.key,
    required this.sessionId,
    required this.apiService,
    required this.onDone,
  });

  @override
  State<FitCheckEvaluationReportPage> createState() => _FitCheckEvaluationReportPageState();
}

class _FitCheckEvaluationReportPageState extends State<FitCheckEvaluationReportPage> {
  FitCheckEvaluation? _evaluation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEvaluation();
  }

  Future<void> _fetchEvaluation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eval = await widget.apiService.getEvaluation(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _evaluation = eval;
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

  Color _recommendationColor(String rec) {
    final lower = rec.toLowerCase();
    if (lower.contains('strong hire')) return FitCheckTheme.success;
    if (lower.contains('hire')) return FitCheckTheme.primary;
    if (lower.contains('leaning hire')) return const Color(0xFF67E8F9);
    if (lower.contains('leaning no hire')) return FitCheckTheme.warning;
    if (lower.contains('no hire')) return FitCheckTheme.error;
    return FitCheckTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitCheckTheme.background,
      appBar: AppBar(
        backgroundColor: FitCheckTheme.surface,
        elevation: 0,
        title: const Text('Post-Interview Evaluation', style: TextStyle(color: FitCheckTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: widget.onDone,
            child: const Text('Done', style: TextStyle(color: FitCheckTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: FitCheckTheme.primary),
                  SizedBox(height: 16),
                  Text('Finalizing evidence analysis & scoring...', style: TextStyle(color: FitCheckTheme.textSecondary)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: FitCheckTheme.error),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: FitCheckTheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchEvaluation,
                          style: ElevatedButton.styleFrom(backgroundColor: FitCheckTheme.primary),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildReportView(_evaluation!),
    );
  }

  Widget _buildReportView(FitCheckEvaluation eval) {
    final recColor = _recommendationColor(eval.overallRecommendation);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recommendation & Overall Score Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FitCheckTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: recColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Overall Recommendation', style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          eval.overallRecommendation,
                          style: TextStyle(color: recColor, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: recColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        eval.overallRecommendation == 'Insufficient Evidence' || eval.overallScore <= 0.0
                            ? 'No Score (Insufficient Signal)'
                            : '${eval.overallScore.toStringAsFixed(1)} / 5.0',
                        style: TextStyle(
                          color: recColor,
                          fontSize: eval.overallRecommendation == 'Insufficient Evidence' || eval.overallScore <= 0.0 ? 14 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (eval.summaryVerdict.isNotEmpty) ...[
                  const Divider(color: FitCheckTheme.borderSubtle, height: 28),
                  Text(
                    eval.summaryVerdict,
                    style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Competency Evidence Scores
          const Text('Competency Rubric Assessment', style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...eval.competencyScores.map((c) {
            final name = c['competency_name'] as String? ?? 'Competency';
            final score = (c['score'] as num?)?.toDouble() ?? 3.0;
            final explanation = c['explanation'] as String? ?? '';
            final citations = (c['evidence_citations'] as List<dynamic>?) ?? [];
            final status = c['status'] as String? ?? 'evaluated';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FitCheckTheme.borderSubtle),
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
                          style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (status == 'insufficient_evidence')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: FitCheckTheme.textMuted.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Insufficient Evidence', style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 11)),
                        )
                      else
                        Text(
                          '${score.toStringAsFixed(1)} / 5.0',
                          style: const TextStyle(color: FitCheckTheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                    ],
                  ),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(explanation, style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13)),
                  ],
                  if (citations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Verified Transcript Evidence:', style: TextStyle(color: FitCheckTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...citations.take(2).map((cit) {
                      final quote = cit['quote'] as String? ?? '';
                      final verified = cit['verified'] as bool? ?? true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(verified ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 14, color: verified ? FitCheckTheme.success : FitCheckTheme.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '"$quote"',
                                style: const TextStyle(color: FitCheckTheme.textPrimary, fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Actionable Preparation & Next Steps
          if (eval.preparationRecommendations.isNotEmpty) ...[
            const Text('Targeted Practice & Preparation Plan', style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FitCheckTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: eval.preparationRecommendations.map((rec) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right, color: FitCheckTheme.primary, size: 20),
                        const SizedBox(width: 6),
                        Expanded(child: Text(rec, style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

