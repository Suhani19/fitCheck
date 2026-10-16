import 'package:flutter/material.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class JobSelectionPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final Function(FitCheckJob job) onJobSelected;

  const JobSelectionPage({
    super.key,
    required this.apiService,
    required this.onJobSelected,
  });

  @override
  State<JobSelectionPage> createState() => _JobSelectionPageState();
}

class _JobSelectionPageState extends State<JobSelectionPage> {
  List<FitCheckJob> _jobs = [];
  bool _loading = false;
  String? _error;

  bool _isCreating = false;
  final _titleController = TextEditingController();
  final _seniorityController = TextEditingController(text: 'Senior');
  final _descriptionController = TextEditingController();
  final _skillsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _seniorityController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    super.dispose();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _createJob() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job title is required.')),
      );
      return;
    }

    final skillsList = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _loading = true);
    try {
      final newJob = await widget.apiService.createJob({
        'title': title,
        'seniority': _seniorityController.text.trim(),
        'description': _descriptionController.text.trim(),
        'required_skills': skillsList,
        'competencies': [
          {
            'name': 'System Architecture & Scale',
            'description': 'Designing scalable distributed architectures',
            'criteria': ['Explains trade-offs and latency boundaries', 'Designs for failure modes'],
            'weight': 1.5,
          },
          {
            'name': 'Operational Reliability',
            'description': 'Monitoring, observability, and debugging',
            'criteria': ['Mitigates cascading failures', 'Defines sensible alerting SLIs'],
            'weight': 1.0,
          },
        ],
      });
      if (!mounted) return;
      setState(() {
        _jobs.insert(0, newJob);
        _isCreating = false;
        _loading = false;
      });
      widget.onJobSelected(newJob);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitCheckTheme.background,
      appBar: AppBar(
        backgroundColor: FitCheckTheme.surface,
        elevation: 0,
        title: const Text('Target Role & Rubric', style: TextStyle(color: FitCheckTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(_isCreating ? Icons.close : Icons.add, color: FitCheckTheme.primary),
            onPressed: () => setState(() => _isCreating = !_isCreating),
            tooltip: _isCreating ? 'Cancel' : 'New Job Role',
          ),
        ],
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

                  if (_isCreating) _buildCreateJobForm() else _buildJobList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateJobForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FitCheckTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FitCheckTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Define Target Job & Rubric',
            style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Job Title (e.g., Staff Backend Architect) *',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _seniorityController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Seniority Level (Junior, Mid, Senior, Principal)',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _skillsController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Required Core Skills (comma separated)',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Job description, team context, and responsibilities...',
              hintStyle: const TextStyle(color: FitCheckTheme.textMuted),
              filled: true,
              fillColor: FitCheckTheme.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save & Select Target Role', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildJobList() {
    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.work_outline_rounded, size: 48, color: FitCheckTheme.textMuted),
              const SizedBox(height: 12),
              const Text('No job postings configured yet.', style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add),
                label: const Text('Create Job Posting'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.background,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Target Role for Interview',
          style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._jobs.map((job) {
          return Card(
            color: FitCheckTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: FitCheckTheme.borderSubtle),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                '${job.title} (${job.seniority})',
                style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.description.isNotEmpty)
                    Text(
                      job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${job.competencies.length} Evaluated Competencies',
                    style: const TextStyle(color: FitCheckTheme.primary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FitCheckTheme.textMuted),
              onTap: () => widget.onJobSelected(job),
            ),
          );
        }),
      ],
    );
  }
}

