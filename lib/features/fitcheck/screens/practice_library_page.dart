import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class PracticeLibraryPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final List<FitCheckEvaluation> evaluations;
  final List<FitCheckSession> sessions;
  final bool isDemoMode;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final ValueChanged<Map<String, dynamic>>? onLaunchDrill;
  final VoidCallback onSignOut;

  const PracticeLibraryPage({
    super.key,
    this.candidate,
    this.currentUser,
    this.evaluations = const [],
    this.sessions = const [],
    this.isDemoMode = false,
    required this.onNavigate,
    required this.onStartInterview,
    this.onLaunchDrill,
    required this.onSignOut,
  });

  @override
  State<PracticeLibraryPage> createState() => _PracticeLibraryPageState();
}

class _PracticeLibraryPageState extends State<PracticeLibraryPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  late List<Map<String, dynamic>> _drills;

  @override
  void initState() {
    super.initState();
    _initDrills();
  }

  @override
  void didUpdateWidget(PracticeLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evaluations != widget.evaluations || oldWidget.sessions != widget.sessions) {
      _initDrills();
    }
  }

  void _initDrills() {
    final baseDrills = [
      {
        'id': 'drill-1',
        'title': 'Raft Split-Brain Recovery',
        'category': 'Distributed Systems',
        'difficulty': 'HARD',
        'duration': '15 min',
        'description': 'Handle network partitions, quorum splits, and reconciliation of split logs.',
        'competencies': ['Consensus', 'Fault Tolerance', 'Network Partitions'],
      },
      {
        'id': 'drill-2',
        'title': 'High-Throughput WAL Compaction',
        'category': 'Storage Systems',
        'difficulty': 'HARD',
        'duration': '20 min',
        'description': 'Design bounded memory snapshot compaction for continuous append-only write-ahead logs.',
        'competencies': ['Write-Ahead Logs', 'LSM Trees', 'Memory Management'],
      },
      {
        'id': 'drill-3',
        'title': 'State Machine Lease Expiry Mitigation',
        'category': 'Distributed Systems',
        'difficulty': 'EXPERT',
        'duration': '25 min',
        'description': 'Mitigate clock skew and lease expiration bugs in multi-leader distributed coordination.',
        'competencies': ['Lease Management', 'Clock Drift', 'Linearizability'],
      },
      {
        'id': 'drill-4',
        'title': 'Lock-Free Ring Buffer Implementation',
        'category': 'Concurrency',
        'difficulty': 'MEDIUM',
        'duration': '15 min',
        'description': 'Construct a zero-allocation single-producer single-consumer ring buffer in Go or C++.',
        'competencies': ['Memory Fences', 'Atomic CAS', 'Cache Lines'],
      },
      {
        'id': 'drill-5',
        'title': 'Distributed Tracing Baggage Propagation',
        'category': 'Observability',
        'difficulty': 'MEDIUM',
        'duration': '15 min',
        'description': 'Implement contextual header injection and trace propagation across asynchronous microservices.',
        'competencies': ['OpenTelemetry', 'Header Injection', 'Sampling'],
      },
      {
        'id': 'drill-6',
        'title': 'gRPC Backpressure & Client Rate Limiting',
        'category': 'Networking',
        'difficulty': 'HARD',
        'duration': '20 min',
        'description': 'Design proactive client-side rate limiting with token-bucket shedding during server overload.',
        'competencies': ['gRPC', 'Flow Control', 'Rate Limiting'],
      },
    ];

    _drills = baseDrills.map((d) {
      // Check if candidate has completed evaluation covering any of these competencies
      int? score;
      bool completed = false;

      if (widget.evaluations.isNotEmpty) {
        for (final ev in widget.evaluations) {
          final comps = d['competencies'] as List<String>;
          final hasMatchingComp = ev.competencyScores.any((c) {
            final name = (c['competency_name'] ?? c['competency'] ?? '').toString().toLowerCase();
            return comps.any((req) => name.contains(req.toLowerCase()));
          });

          if (hasMatchingComp) {
            completed = true;
            score = (ev.overallScore <= 5.0 ? ev.overallScore * 20 : ev.overallScore).round();
            break;
          }
        }
      }

      return {
        ...d,
        'completed': completed,
        'score': score,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final categories = ['All', 'Distributed Systems', 'Storage Systems', 'Concurrency', 'Networking', 'Observability'];

    final filtered = _drills.where((d) {
      final matchesCategory = _selectedCategory == 'All' || d['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          (d['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (d['description'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.practiceLibrary,
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
                      constraints: const BoxConstraints(maxWidth: 1300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(isDesktop),
                          const SizedBox(height: 20),
                          _buildFilterBar(categories),
                          const SizedBox(height: 24),
                          _buildDrillGrid(filtered, isDesktop),
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
              Text('PRACTICE LIBRARY', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Curated High-Yield Drills', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          ElevatedButton.icon(
            key: const Key('practice_start_interview_header_btn'),
            onPressed: widget.onStartInterview,
            icon: const Icon(Icons.mic, size: 14),
            label: const Text('Start Simulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: Text('CURATED BENCHMARKS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                ),
                const SizedBox(width: 8),
                Text('STANDARDIZED SPARRING', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Targeted Practice Drills', style: FitCheckTheme.headlineMedium()),
            const SizedBox(height: 6),
            Text(
              'Focused 15–25 minute problem scenarios targeting specific architectural competencies. (Curated engineering challenges).',
              style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar(List<String> categories) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSel,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    backgroundColor: FitCheckTheme.surfaceContainerLow,
                    selectedColor: FitCheckTheme.surfaceContainerHigh,
                    labelStyle: TextStyle(
                      color: isSel ? FitCheckTheme.primary : FitCheckTheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: isSel ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 220,
          height: 38,
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 12, color: FitCheckTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search drills...',
              hintStyle: const TextStyle(fontSize: 12, color: FitCheckTheme.outline),
              prefixIcon: const Icon(Icons.search, size: 16, color: FitCheckTheme.outline),
              contentPadding: EdgeInsets.zero,
              filled: true,
              fillColor: FitCheckTheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: FitCheckTheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: FitCheckTheme.outlineVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrillGrid(List<Map<String, dynamic>> drills, bool isDesktop) {
    if (drills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: FitCheckTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FitCheckTheme.outlineVariant),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 48, color: FitCheckTheme.outline),
            const SizedBox(height: 12),
            Text('No practice drills found', style: FitCheckTheme.titleMedium()),
            const SizedBox(height: 4),
            Text('Try selecting a different category or clearing your search.', style: FitCheckTheme.bodySmall()),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: drills.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final drill = drills[index];
            final completed = drill['completed'] as bool;

            return Container(
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
                          color: FitCheckTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          drill['category'] as String,
                          style: const TextStyle(fontSize: 10, color: FitCheckTheme.outline),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: drill['difficulty'] == 'EXPERT'
                              ? FitCheckTheme.error.withValues(alpha: 0.15)
                              : FitCheckTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          drill['difficulty'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: drill['difficulty'] == 'EXPERT' ? FitCheckTheme.error : FitCheckTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    drill['title'] as String,
                    style: FitCheckTheme.titleMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      drill['description'] as String,
                      style: FitCheckTheme.bodySmall(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (drill['competencies'] as List<String>).map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 9, color: FitCheckTheme.onSurfaceVariant)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: FitCheckTheme.outline),
                          const SizedBox(width: 4),
                          Text(drill['duration'] as String, style: const TextStyle(fontSize: 11, color: FitCheckTheme.outline)),
                          if (completed) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle, size: 13, color: FitCheckTheme.tertiary),
                            const SizedBox(width: 4),
                            Text('${drill['score']}%', style: const TextStyle(fontSize: 11, color: FitCheckTheme.tertiary, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                      OutlinedButton(
                        key: Key('start_drill_btn_${drill['id']}'),
                        onPressed: () {
                          if (widget.onLaunchDrill != null) {
                            widget.onLaunchDrill!(drill);
                          } else {
                            widget.onStartInterview();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FitCheckTheme.primary,
                          side: const BorderSide(color: FitCheckTheme.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(completed ? 'Retake' : 'Launch', style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
