import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class FitCheckHistoryPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final Function(String sessionId) onSelectSession;

  const FitCheckHistoryPage({
    super.key,
    required this.apiService,
    required this.onSelectSession,
  });

  @override
  State<FitCheckHistoryPage> createState() => _FitCheckHistoryPageState();
}

class _FitCheckHistoryPageState extends State<FitCheckHistoryPage> {
  List<FitCheckSession> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list;
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
        title: const Text('Past Interview Simulations', style: TextStyle(color: FitCheckTheme.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FitCheckTheme.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: FitCheckTheme.error)))
              : _sessions.isEmpty
                  ? const Center(
                      child: Text('No past interview sessions found.', style: TextStyle(color: FitCheckTheme.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final sess = _sessions[index];
                        final diffColor = FitCheckTheme.difficultyColor(sess.difficulty);

                        return Card(
                          color: FitCheckTheme.surface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: FitCheckTheme.borderSubtle),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              'Interview Session',
                              style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: diffColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sess.difficulty.toUpperCase(),
                                        style: TextStyle(color: diffColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Status: ${sess.status}',
                                      style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FitCheckTheme.textMuted),
                            onTap: () => widget.onSelectSession(sess.id),
                          ),
                        );
                      },
                    ),
    );
  }
}

