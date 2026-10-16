import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class TargetJobsPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final ValueChanged<FitCheckJob>? onSelectJob;
  final VoidCallback onSignOut;

  const TargetJobsPage({
    super.key,
    required this.apiService,
    this.candidate,
    this.currentUser,
    required this.onNavigate,
    required this.onStartInterview,
    this.onSelectJob,
    required this.onSignOut,
  });

  @override
  State<TargetJobsPage> createState() => _TargetJobsPageState();
}

class _TargetJobsPageState extends State<TargetJobsPage> {
  List<FitCheckJob> _jobs = [];
  bool _loading = true;
  String? _error;
  FitCheckJob? _selectedJob;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _skillsCtrl = TextEditingController();
  String _seniority = 'senior';
  bool _showCreateJobCard = false;
  bool _generatingRubric = false;
  bool _savingJob = false;
  String? _rubricError;
  List<Map<String, dynamic>>? _generatedCompetencies;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateRubric() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a role title and role description to synthesize rubrics.'),
          backgroundColor: FitCheckTheme.warning,
        ),
      );
      return;
    }

    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() {
      _generatingRubric = true;
      _rubricError = null;
    });

    try {
      final result = await widget.apiService.generateRubric(
        title: title,
        description: desc,
        seniority: _seniority,
        requiredSkills: skills,
      );
      if (!mounted) return;
      setState(() {
        _generatedCompetencies = result;
        _generatingRubric = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synthesized ${result.length} observable evaluation criteria. Review below before saving.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generatingRubric = false;
        _rubricError = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rubric generation failed: $_rubricError'),
          backgroundColor: FitCheckTheme.error,
        ),
      );
    }
  }

  Future<void> _handleSaveJob() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a role title and description.'),
          backgroundColor: FitCheckTheme.warning,
        ),
      );
      return;
    }

    final skills = _skillsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _savingJob = true);

    try {
      final created = await widget.apiService.createJob({
        'title': title,
        'seniority': _seniority,
        'description': desc,
        'required_skills': skills.isNotEmpty ? skills : ['System Design', 'Technical Trade-offs'],
        'competencies': _generatedCompetencies ?? [],
      });
      if (!mounted) return;
      setState(() {
        _jobs.removeWhere((j) => j.id == created.id);
        _jobs.insert(0, created);
        _selectedJob = created;
        _showCreateJobCard = false;
        _savingJob = false;
        _generatedCompetencies = null;
        _titleCtrl.clear();
        _descCtrl.clear();
        _skillsCtrl.clear();
      });
      widget.onSelectJob?.call(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target role "${created.title}" with rubric calibrated successfully.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingJob = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to persist target role: $e'),
          backgroundColor: FitCheckTheme.error,
        ),
      );
    }
  }

  Future<void> _fetchJobs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.listJobs();
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loading = false;
        if (list.isNotEmpty) _selectedJob = list.first;
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
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: FitCheckTheme.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            CandidateSidebar(
              currentRoute: FitCheckRoute.targetJobs,
              candidate: widget.candidate,
              currentUser: widget.currentUser,
              onNavigate: widget.onNavigate,
              onStartInterview: widget.onStartInterview,
              onSignOut: widget.onSignOut,
            ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(isDesktop),
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
                          if (_showCreateJobCard) ...[
                            const SizedBox(height: 20),
                            _buildCreateJobWithRubricCard(),
                          ],
                          const SizedBox(height: 24),
                          if (_loading)
                            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: FitCheckTheme.primary)))
                          else if (_error != null && _jobs.isEmpty)
                            _buildErrorState()
                          else if (_jobs.isEmpty)
                            _buildEmptyState()
                          else
                            _buildJobsContent(isDesktop),
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

  Widget _buildHeader(bool isDesktop) {
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
                  icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurface, size: 20),
                  onPressed: () => widget.onNavigate(FitCheckRoute.commandCenter),
                ),
                const SizedBox(width: 8),
              ],
              Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 6),
              Text('Target Jobs & Competency Rubrics', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          ElevatedButton.icon(
            onPressed: widget.onStartInterview,
            icon: const Icon(Icons.mic, size: 14),
            label: const Text('Start Simulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('ROLE BENCHMARKS & RUBRICS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                ),
                const SizedBox(width: 8),
                Text('HIRING BAR CALIBRATION', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              ],
            ),
            OutlinedButton.icon(
              key: const Key('add_target_job_toggle_btn'),
              onPressed: () => setState(() => _showCreateJobCard = !_showCreateJobCard),
              icon: Icon(_showCreateJobCard ? Icons.expand_less : Icons.add_circle_outline, size: 16),
              label: Text(_showCreateJobCard ? 'Hide Role Form' : 'Add Role & Synthesize Rubric'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FitCheckTheme.primary,
                side: const BorderSide(color: FitCheckTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Target Jobs & Competency Rubrics', style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Target role competencies, seniority benchmarks, and scoring rubrics calibrated against FAANG & Tier-1 tech standards.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildCreateJobWithRubricCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: FitCheckTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'TARGET ROLE SPECIFICATION & OBSERVABLE RUBRICS',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Define a target role or paste a job description. FitCheck synthesizes 3-5 observable evaluation competencies with scoring anchors for rigorous Socratic probing.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 7,
                child: TextField(
                  key: const Key('rubric_job_title_input'),
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Job Title',
                    hintText: 'e.g. Staff Distributed Systems Architect, Principal Platform Engineer',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: FitCheckTheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: FitCheckTheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const Key('rubric_job_seniority_dropdown'),
                      value: _seniority,
                      dropdownColor: FitCheckTheme.surfaceContainerHigh,
                      items: const [
                        DropdownMenuItem(value: 'senior', child: Text('Senior (L5)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'staff', child: Text('Staff (L6)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'principal', child: Text('Principal (L7)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'lead', child: Text('Lead / Manager', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'mid', child: Text('Mid-Level (L4)', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _seniority = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rubric_job_skills_input'),
            controller: _skillsCtrl,
            decoration: const InputDecoration(
              labelText: 'Key Required Skills (Comma-Separated)',
              hintText: 'e.g. Distributed Consensus, Raft, KV Storage, Concurrency, Sharding',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rubric_job_desc_input'),
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Job Description or Role Requirements',
              hintText: 'Paste job responsibilities, architectural scope, and technical depth expectations...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                key: const Key('generate_rubric_ai_btn'),
                onPressed: _generatingRubric ? null : _handleGenerateRubric,
                icon: _generatingRubric
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.primary))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_generatingRubric ? 'Synthesizing Observable Rubrics...' : 'Generate Rubric via AI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.primary,
                  side: const BorderSide(color: FitCheckTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _showCreateJobCard = false;
                  _generatedCompetencies = null;
                }),
                child: const Text('Cancel', style: TextStyle(color: FitCheckTheme.outline)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                key: const Key('save_job_rubric_btn'),
                onPressed: _savingJob ? null : _handleSaveJob,
                icon: _savingJob
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Save Target Role & Rubric'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (_generatedCompetencies != null && _generatedCompetencies!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl, color: FitCheckTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'SYNTHESIZED OBSERVABLE COMPETENCY RUBRICS (${_generatedCompetencies!.length} CRITERIA MATRICES)',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final comp in _generatedCompetencies!)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: FitCheckTheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                comp['name']?.toString() ?? 'Competency',
                                style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FitCheckTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Weight: ${comp['weight'] ?? 1.0}x',
                                  style: const TextStyle(color: FitCheckTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (comp['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              comp['description'].toString(),
                              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                            ),
                          ],
                          if (comp['criteria'] is List && (comp['criteria'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final crit in (comp['criteria'] as List))
                              Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: FitCheckTheme.primary, fontSize: 13)),
                                    Expanded(
                                      child: Text(crit.toString(), style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.work_outline, size: 48, color: FitCheckTheme.outline),
            const SizedBox(height: 16),
            Text('No Target Jobs Configured', style: FitCheckTheme.headlineMedium()),
            const SizedBox(height: 8),
            Text(
              'Add target job postings or generate dynamic rubrics to calibrate your interview simulations.',
              style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FitCheckTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: FitCheckTheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: FitCheckTheme.bodySmall(color: FitCheckTheme.error))),
          TextButton(onPressed: _fetchJobs, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildJobsContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Jobs list cards
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _jobs.length,
          itemBuilder: (context, i) {
            final job = _jobs[i];
            final isSelected = _selectedJob?.id == job.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSelected ? FitCheckTheme.surfaceContainerHigh : FitCheckTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                onExpansionChanged: (open) {
                  if (open) setState(() => _selectedJob = job);
                },
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        job.seniority.toUpperCase(),
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        job.title,
                        style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    job.description.isNotEmpty ? job.description : 'Calibrated hiring standard for systems architecture.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REQUIRED SKILLS & COMPETENCIES', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: job.requiredSkills.map((sk) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: FitCheckTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(sk, style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary)),
                            );
                          }).toList(),
                        ),
                        if (job.competencies.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('OBSERVABLE EVALUATION RUBRIC CRITERIA', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
                          const SizedBox(height: 8),
                          for (final comp in job.competencies)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: FitCheckTheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: FitCheckTheme.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        comp['name']?.toString() ?? 'Competency',
                                        style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      if (comp['weight'] != null)
                                        Text(
                                          'Weight: ${comp['weight']}x',
                                          style: const TextStyle(fontSize: 10, color: FitCheckTheme.primary, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                  if (comp['description'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(comp['description'].toString(), style: FitCheckTheme.labelSmall(color: FitCheckTheme.onSurfaceVariant)),
                                  ],
                                  if (comp['criteria'] is List) ...[
                                    const SizedBox(height: 4),
                                    for (final c in (comp['criteria'] as List))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                                        child: Text('• $c', style: const TextStyle(fontSize: 11, color: FitCheckTheme.onSurface)),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                widget.onSelectJob?.call(job);
                                widget.onStartInterview();
                              },
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: Text('Calibrate Simulation for ${job.title}'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FitCheckTheme.primary,
                                foregroundColor: FitCheckTheme.onPrimary,
                              ),
                            ),
                            if (job.competencies.isEmpty) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                key: Key('generate_rubric_for_job_${job.id}'),
                                onPressed: () {
                                  setState(() {
                                    _titleCtrl.text = job.title;
                                    _descCtrl.text = job.description;
                                    _seniority = job.seniority.toLowerCase();
                                    _skillsCtrl.text = job.requiredSkills.join(', ');
                                    _showCreateJobCard = true;
                                    _generatedCompetencies = null;
                                  });
                                  _handleGenerateRubric();
                                },
                                icon: const Icon(Icons.auto_awesome, size: 14),
                                label: const Text('Synthesize AI Rubric'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: FitCheckTheme.secondary,
                                  side: const BorderSide(color: FitCheckTheme.secondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
