import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../services/interviewer_recommendation_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class InterviewerLibraryPage extends StatefulWidget {
  final FitCheckApiService apiService;
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;
  final FitCheckInterviewer? selectedInterviewer;
  final FitCheckJob? selectedJob;
  final List<FitCheckInterviewer>? initialInterviewers;
  final List<FitCheckJob>? initialJobs;
  final ValueChanged<FitCheckInterviewer>? onSelectInterviewer;
  final ValueChanged<FitCheckJob?>? onSelectJob;
  final ValueChanged<FitCheckJob>? onCustomJobCreated;

  const InterviewerLibraryPage({
    super.key,
    required this.apiService,
    this.candidate,
    this.currentUser,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
    this.selectedInterviewer,
    this.selectedJob,
    this.initialInterviewers,
    this.initialJobs,
    this.onSelectInterviewer,
    this.onSelectJob,
    this.onCustomJobCreated,
  });

  @override
  State<InterviewerLibraryPage> createState() => _InterviewerLibraryPageState();
}

class _InterviewerLibraryPageState extends State<InterviewerLibraryPage> {
  List<FitCheckInterviewer> _interviewers = [];
  List<FitCheckJob> _jobs = [];
  bool _loading = true;
  String? _error;

  FitCheckInterviewer? _selectedInterviewer;
  FitCheckJob? _selectedJob;

  bool _showCustomJobForm = false;
  final TextEditingController _customJobTitleCtrl = TextEditingController();
  final TextEditingController _customJobSeniorityCtrl = TextEditingController(text: 'Senior (L5/L6)');
  final TextEditingController _customJobDescCtrl = TextEditingController();
  bool _savingCustomJob = false;

  bool _showCustomInterviewerForm = false;
  final TextEditingController _customInterviewerNameCtrl = TextEditingController();
  final TextEditingController _customInterviewerTitleCtrl = TextEditingController();
  final TextEditingController _customInterviewerCompanyCtrl = TextEditingController();
  final TextEditingController _customInterviewerNotesCtrl = TextEditingController();
  String _customInterviewerStyle = 'conversational';
  String _customInterviewerVoice = 'Puck';
  bool _personalizingInterviewer = false;
  bool _savingCustomInterviewer = false;
  Map<String, dynamic>? _personalizedPreview;

  @override
  void initState() {
    super.initState();
    _selectedInterviewer = widget.selectedInterviewer;
    _selectedJob = widget.selectedJob;
    if (widget.initialInterviewers != null && widget.initialInterviewers!.isNotEmpty) {
      _interviewers = List.from(widget.initialInterviewers!);
    }
    if (widget.initialJobs != null && widget.initialJobs!.isNotEmpty) {
      _jobs = List.from(widget.initialJobs!);
    }
    _fetchData();
  }

  List<FitCheckJob> _getDeduplicatedJobs() {
    final seen = <String>{};
    final result = <FitCheckJob>[];
    for (final job in _jobs) {
      if (job.id.isNotEmpty && !seen.contains(job.id)) {
        seen.add(job.id);
        result.add(job);
      }
    }
    return result;
  }

  @override
  void didUpdateWidget(covariant InterviewerLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedInterviewer != oldWidget.selectedInterviewer) {
      setState(() => _selectedInterviewer = widget.selectedInterviewer);
    }
    if (widget.selectedJob != oldWidget.selectedJob) {
      final job = widget.selectedJob;
      setState(() {
        _selectedJob = job;
        if (job != null && !_jobs.any((j) => j.id == job.id)) {
          _jobs.insert(0, job);
        }
      });
    }
  }

  @override
  void dispose() {
    _customJobTitleCtrl.dispose();
    _customJobSeniorityCtrl.dispose();
    _customJobDescCtrl.dispose();
    _customInterviewerNameCtrl.dispose();
    _customInterviewerTitleCtrl.dispose();
    _customInterviewerCompanyCtrl.dispose();
    _customInterviewerNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = _interviewers.isEmpty;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        widget.apiService.listInterviewers(),
        widget.apiService.listJobs(),
      ]);
      if (!mounted) return;
      final interviewers = futures[0] as List<FitCheckInterviewer>;
      final jobs = futures[1] as List<FitCheckJob>;
      final seen = <String>{};
      final uniqueJobs = jobs.where((j) => j.id.isNotEmpty && seen.add(j.id)).toList();
      setState(() {
        _interviewers = interviewers;
        _jobs = uniqueJobs;
        _loading = false;
        if (_selectedInterviewer == null && interviewers.isNotEmpty) {
          _selectedInterviewer = interviewers.first;
        }
        if (_selectedJob != null && !_jobs.any((j) => j.id == _selectedJob!.id)) {
          _selectedJob = null;
          widget.onSelectJob?.call(null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handleSaveCustomJob() async {
    final title = _customJobTitleCtrl.text.trim();
    final desc = _customJobDescCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both a job title and job description.'),
          backgroundColor: FitCheckTheme.warning,
        ),
      );
      return;
    }

    setState(() => _savingCustomJob = true);
    try {
      final created = await widget.apiService.createJob({
        'title': title,
        'seniority': _customJobSeniorityCtrl.text.trim().isNotEmpty ? _customJobSeniorityCtrl.text.trim() : 'Senior',
        'description': desc,
        'required_skills': ['System Design', 'Technical Trade-offs'],
      });
      if (!mounted) return;
      setState(() {
        _jobs.removeWhere((j) => j.id == created.id);
        _jobs.insert(0, created);
        _selectedJob = created;
        _showCustomJobForm = false;
        _savingCustomJob = false;
      });
      widget.onSelectJob?.call(created);
      widget.onCustomJobCreated?.call(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved target job: "${created.title}". Matched interviewers below.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // In demo mode or offline, create client-side job object
      final clientJob = FitCheckJob(
        id: 'job-custom-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        seniority: _customJobSeniorityCtrl.text.trim().isNotEmpty ? _customJobSeniorityCtrl.text.trim() : 'Senior',
        description: desc,
        requiredSkills: const ['System Design', 'Technical Trade-offs'],
      );
      setState(() {
        _jobs.removeWhere((j) => j.id == clientJob.id);
        _jobs.insert(0, clientJob);
        _selectedJob = clientJob;
        _showCustomJobForm = false;
        _savingCustomJob = false;
      });
      widget.onSelectJob?.call(clientJob);
      widget.onCustomJobCreated?.call(clientJob);
    }
  }

  Future<void> _handlePersonalizeInterviewer() async {
    final name = _customInterviewerNameCtrl.text.trim();
    final title = _customInterviewerTitleCtrl.text.trim();
    if (name.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an interviewer name and title/seniority.'),
          backgroundColor: FitCheckTheme.warning,
        ),
      );
      return;
    }

    setState(() {
      _personalizingInterviewer = true;
      _personalizedPreview = null;
    });

    try {
      final res = await widget.apiService.personalizeInterviewer({
        'name': name,
        'title': title,
        'company_context': _customInterviewerCompanyCtrl.text.trim().isNotEmpty
            ? _customInterviewerCompanyCtrl.text.trim()
            : null,
        'user_notes': _customInterviewerNotesCtrl.text.trim().isNotEmpty
            ? _customInterviewerNotesCtrl.text.trim()
            : null,
        'questioning_style': _customInterviewerStyle,
        'voice_id': _customInterviewerVoice,
      });
      if (!mounted) return;
      setState(() {
        _personalizedPreview = res;
        _personalizingInterviewer = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Client-side fallback preview if offline or mock
      final company = _customInterviewerCompanyCtrl.text.trim();
      final notes = _customInterviewerNotesCtrl.text.trim();
      final fallbackBio = notes.isNotEmpty
          ? notes
          : '$name is a $title${company.isNotEmpty ? ' at $company' : ''} specializing in deep architectural evaluation.';
      final preview = <String, dynamic>{
        'name': name,
        'title': title,
        'bio': fallbackBio,
        'company_context': company.isNotEmpty ? company : null,
        'questioning_style': _customInterviewerStyle,
        'voice_id': _customInterviewerVoice,
        'provenance': {
          'verified_facts': company.isNotEmpty
              ? [
                  {'fact': 'Experience with $company', 'source': 'Candidate Input'}
                ]
              : [],
          'inferred_style': {
            'focus_areas': notes.isNotEmpty
                ? notes.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                : ['System Architecture', 'Production Trade-offs'],
          },
          'disclaimer': 'FitCheck provides an AI simulation for practice and preparation purposes, not the actual person\'s participation or endorsement.',
        },
      };
      setState(() {
        _personalizedPreview = preview;
        _personalizingInterviewer = false;
      });
    }
  }

  Future<void> _handleSaveCustomInterviewer() async {
    final name = _customInterviewerNameCtrl.text.trim();
    final title = _customInterviewerTitleCtrl.text.trim();
    if (name.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an interviewer name and title.'),
          backgroundColor: FitCheckTheme.warning,
        ),
      );
      return;
    }

    setState(() => _savingCustomInterviewer = true);

    final payload = _personalizedPreview != null
        ? Map<String, dynamic>.from(_personalizedPreview!)
        : <String, dynamic>{
            'name': name,
            'title': title,
            'bio': _customInterviewerNotesCtrl.text.trim().isNotEmpty
                ? _customInterviewerNotesCtrl.text.trim()
                : null,
            'company_context': _customInterviewerCompanyCtrl.text.trim().isNotEmpty
                ? _customInterviewerCompanyCtrl.text.trim()
                : null,
            'questioning_style': _customInterviewerStyle,
            'voice_id': _customInterviewerVoice,
            'provenance': {
              'inferred_style': {
                'focus_areas': ['System Architecture', 'Technical Trade-offs'],
              },
              'disclaimer': 'FitCheck provides an AI simulation for practice and preparation purposes.',
            },
          };

    try {
      final created = await widget.apiService.createInterviewer(payload);
      if (!mounted) return;
      setState(() {
        _interviewers.removeWhere((i) => i.id == created.id);
        _interviewers.insert(0, created);
        _selectedInterviewer = created;
        _showCustomInterviewerForm = false;
        _savingCustomInterviewer = false;
        _personalizedPreview = null;
        _customInterviewerNameCtrl.clear();
        _customInterviewerTitleCtrl.clear();
        _customInterviewerCompanyCtrl.clear();
        _customInterviewerNotesCtrl.clear();
      });
      widget.onSelectInterviewer?.call(created);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created custom interviewer: "${created.name}". Selected for practice.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Client-side fallback if backend creation failed
      final clientInterviewer = FitCheckInterviewer(
        id: 'interviewer-custom-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        title: title,
        companyContext: payload['company_context'] as String?,
        questioningStyle: _customInterviewerStyle,
        voiceId: _customInterviewerVoice,
        isPreset: false,
        bio: payload['bio'] as String?,
        provenance: payload['provenance'] as Map<String, dynamic>?,
      );
      setState(() {
        _interviewers.removeWhere((i) => i.id == clientInterviewer.id);
        _interviewers.insert(0, clientInterviewer);
        _selectedInterviewer = clientInterviewer;
        _showCustomInterviewerForm = false;
        _savingCustomInterviewer = false;
        _personalizedPreview = null;
        _customInterviewerNameCtrl.clear();
        _customInterviewerTitleCtrl.clear();
        _customInterviewerCompanyCtrl.clear();
        _customInterviewerNotesCtrl.clear();
      });
      widget.onSelectInterviewer?.call(clientInterviewer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created custom interviewer: "${clientInterviewer.name}". Selected for practice.'),
          backgroundColor: FitCheckTheme.tertiary,
        ),
      );
    }
  }

  void _handleSelectInterviewer(FitCheckInterviewer interviewer) {
    setState(() => _selectedInterviewer = interviewer);
    if (widget.onSelectInterviewer != null) {
      widget.onSelectInterviewer!(interviewer);
    } else {
      widget.onStartInterview();
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
              currentRoute: FitCheckRoute.interviewerLibrary,
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
                          const SizedBox(height: 20),
                          _buildJobRecommendationContextBar(isDesktop),
                          if (_showCustomJobForm) ...[
                            const SizedBox(height: 16),
                            _buildCustomJobInputCard(),
                          ],
                          if (_showCustomInterviewerForm) ...[
                            const SizedBox(height: 16),
                            _buildCustomInterviewerInputCard(),
                          ],
                          const SizedBox(height: 24),
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(color: FitCheckTheme.primary),
                              ),
                            )
                          else if (_error != null && _interviewers.isEmpty)
                            _buildErrorState()
                          else if (_interviewers.isEmpty)
                            _buildEmptyState()
                          else
                            _buildInterviewersGrid(isDesktop),
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
          Expanded(
            child: Row(
              children: [
                if (!isDesktop) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: FitCheckTheme.onSurface, size: 20),
                    onPressed: () => widget.onNavigate(FitCheckRoute.commandCenter),
                  ),
                  const SizedBox(width: 8),
                ],
                const FitCheckLogo(size: 16),
                const SizedBox(width: 8),
                Text('FitCheck', style: FitCheckTheme.bodySmall(color: FitCheckTheme.outline)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Interviewer Library & Persona Detail',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            key: const Key('library_start_interview_top_button'),
            onPressed: () {
              if (_selectedInterviewer != null && widget.onSelectInterviewer != null) {
                widget.onSelectInterviewer!(_selectedInterviewer!);
              } else {
                widget.onStartInterview();
              }
            },
            icon: const Icon(Icons.mic, size: 14),
            label: Text(
              _selectedInterviewer != null
                  ? 'Start with ${_selectedInterviewer!.name.split(' ').first}'
                  : 'Start Simulation',
            ),
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
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('AI SYNTHETIC INTERVIEWER CATALOG', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary)),
            ),
            Text('JOB-AWARE CALIBRATION & PERSISTENT SELECTION', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Interviewer Library & Style Matrix', style: isDesktop ? FitCheckTheme.headlineXLarge() : FitCheckTheme.headlineMedium()),
        const SizedBox(height: 6),
        Text(
          'Select an AI interviewer persona calibrated for your target domain, systems architecture, or leadership bar. Your selection persists across setup, hardware readiness, and live simulation.',
          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildJobRecommendationContextBar(bool isDesktop) {
    final hasJob = _selectedJob != null;
    final uniqueJobs = _getDeduplicatedJobs();

    // Validate selected value against the current items
    String dropdownValue = '__none__';
    if (_selectedJob != null) {
      final exists = uniqueJobs.any((j) => j.id == _selectedJob!.id);
      if (exists) {
        dropdownValue = _selectedJob!.id;
      } else if (_loading) {
        // While still loading from API, preserve selected job temporarily in options
        uniqueJobs.insert(0, _selectedJob!);
        dropdownValue = _selectedJob!.id;
      } else {
        // Finished loading and selected job is truly not present; clear invalid selection
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedJob != null) {
            setState(() => _selectedJob = null);
            widget.onSelectJob?.call(null);
          }
        });
        dropdownValue = '__none__';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasJob ? FitCheckTheme.primary.withValues(alpha: 0.3) : FitCheckTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasJob ? Icons.work : Icons.tune,
                    color: hasJob ? FitCheckTheme.primary : FitCheckTheme.outline,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TARGET ROLE & RECOMMENDATION ALIGNMENT',
                    style: FitCheckTheme.labelSmall(color: hasJob ? FitCheckTheme.primary : FitCheckTheme.outline)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (hasJob)
                TextButton.icon(
                  key: const Key('library_clear_job_filter_button'),
                  onPressed: () {
                    setState(() => _selectedJob = null);
                    widget.onSelectJob?.call(null);
                  },
                  icon: const Icon(Icons.close, size: 14, color: FitCheckTheme.outline),
                  label: const Text('Clear Filter (General Practice)', style: TextStyle(color: FitCheckTheme.outline, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Job Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    key: const Key('library_job_selector_dropdown'),
                    value: dropdownValue,
                    dropdownColor: FitCheckTheme.surfaceContainerHigh,
                    items: [
                      const DropdownMenuItem(
                        value: '__none__',
                        child: Text(
                          'General Technical Practice (Browse All)',
                          style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                      ...uniqueJobs.map((j) {
                        return DropdownMenuItem(
                          value: j.id,
                          child: Text(
                            '${j.title} (${j.seniority})',
                            style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val == null || val == '__none__') {
                        setState(() => _selectedJob = null);
                        widget.onSelectJob?.call(null);
                      } else {
                        final matched = uniqueJobs.where((j) => j.id == val).firstOrNull;
                        setState(() => _selectedJob = matched);
                        widget.onSelectJob?.call(matched);
                      }
                    },
                  ),
                ),
              ),

              // Button to paste custom job description
              OutlinedButton.icon(
                key: const Key('library_paste_job_button'),
                onPressed: () {
                  setState(() => _showCustomJobForm = !_showCustomJobForm);
                },
                icon: Icon(_showCustomJobForm ? Icons.expand_less : Icons.post_add, size: 16),
                label: Text(_showCustomJobForm ? 'Hide Job Form' : 'Paste Job Description'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.primary,
                  side: const BorderSide(color: FitCheckTheme.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),

              // Button to personalize custom interviewer persona
              OutlinedButton.icon(
                key: const Key('library_create_custom_interviewer_button'),
                onPressed: () {
                  setState(() => _showCustomInterviewerForm = !_showCustomInterviewerForm);
                },
                icon: Icon(_showCustomInterviewerForm ? Icons.expand_less : Icons.person_add_outlined, size: 16),
                label: Text(_showCustomInterviewerForm ? 'Hide Interviewer Form' : 'Personalize Interviewer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.tertiary,
                  side: const BorderSide(color: FitCheckTheme.tertiary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
          if (hasJob) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FitCheckTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Calibrated for ${_selectedJob!.title} (${_selectedJob!.seniority}). Interviewers below are ranked by domain match score, but you can select any persona.',
                style: const TextStyle(color: FitCheckTheme.primary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomJobInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.description_outlined, color: FitCheckTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text('ENTER TARGET JOB POSTING', style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: TextField(
                  key: const Key('custom_job_title_input'),
                  controller: _customJobTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target Job Title (e.g. Staff Distributed Systems Engineer)',
                    hintText: 'e.g. Principal Backend Architect',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  key: const Key('custom_job_seniority_input'),
                  controller: _customJobSeniorityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Seniority Level',
                    hintText: 'e.g. Staff L6, Principal, Senior',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('custom_job_desc_input'),
            controller: _customJobDescCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Job Description or Requirements',
              hintText: 'Paste the job requirements, responsibilities, or technical stack here...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _showCustomJobForm = false),
                child: const Text('Cancel', style: TextStyle(color: FitCheckTheme.outline)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('custom_job_save_button'),
                onPressed: _savingCustomJob ? null : _handleSaveCustomJob,
                icon: _savingCustomJob
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Apply & Rank Recommendations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.primary,
                  foregroundColor: FitCheckTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInterviewerInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FitCheckTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_outlined, color: FitCheckTheme.tertiary, size: 18),
              const SizedBox(width: 8),
              Text(
                'CUSTOM INTERVIEWER PERSONA & CALIBRATION',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Personalize an AI interviewer persona with specific company context, questioning strictness, and voice profile.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextField(
                  key: const Key('custom_interviewer_name_input'),
                  controller: _customInterviewerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Interviewer Name',
                    hintText: 'e.g. Alex Rivera, Dr. Aris Thorne',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: TextField(
                  key: const Key('custom_interviewer_title_input'),
                  controller: _customInterviewerTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Role / Seniority',
                    hintText: 'e.g. Staff Distributed Systems Architect',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  key: const Key('custom_interviewer_company_input'),
                  controller: _customInterviewerCompanyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Company Context (Optional)',
                    hintText: 'e.g. Stripe, AWS, Netflix',
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
                      key: const Key('custom_interviewer_style_dropdown'),
                      value: _customInterviewerStyle,
                      dropdownColor: FitCheckTheme.surfaceContainerHigh,
                      items: const [
                        DropdownMenuItem(value: 'conversational', child: Text('Conversational', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'rigorous', child: Text('Rigorous Socratic', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'challenging', child: Text('Challenging / Stress', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'empathetic', child: Text('Empathetic Coach', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _customInterviewerStyle = val);
                      },
                    ),
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
                      key: const Key('custom_interviewer_voice_dropdown'),
                      value: _customInterviewerVoice,
                      dropdownColor: FitCheckTheme.surfaceContainerHigh,
                      items: const [
                        DropdownMenuItem(value: 'Puck', child: Text('Puck (Conversational)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Aoede', child: Text('Aoede (Calibrated Female)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Fenrir', child: Text('Fenrir (Authoritative Male)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Charon', child: Text('Charon (Analytical Male)', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'Kore', child: Text('Kore (Relaxed Female)', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _customInterviewerVoice = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('custom_interviewer_notes_input'),
            controller: _customInterviewerNotesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Interviewer Calibration Notes & Focus Topics',
              hintText: 'e.g. Probes Raft consensus edge cases, clock skew, dynamic programming invariant proofs, leadership conflict resolution...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_personalizedPreview != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: FitCheckTheme.tertiary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'SYNTHESIZED PERSONA PREVIEW',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _personalizedPreview!['bio']?.toString() ?? '',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                  ),
                  if (_personalizedPreview!['provenance'] is Map &&
                      (_personalizedPreview!['provenance']['inferred_style']?['focus_areas'] is List)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final area in (_personalizedPreview!['provenance']['inferred_style']['focus_areas'] as List))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              area.toString(),
                              style: const TextStyle(color: FitCheckTheme.tertiary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_personalizedPreview!['provenance']?['disclaimer'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _personalizedPreview!['provenance']['disclaimer'].toString(),
                      style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant).copyWith(fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _showCustomInterviewerForm = false;
                  _personalizedPreview = null;
                }),
                child: const Text('Cancel', style: TextStyle(color: FitCheckTheme.outline)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('custom_interviewer_personalize_button'),
                onPressed: _personalizingInterviewer ? null : _handlePersonalizeInterviewer,
                icon: _personalizingInterviewer
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.tertiary))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Synthesize Persona via AI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FitCheckTheme.tertiary,
                  side: const BorderSide(color: FitCheckTheme.tertiary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                key: const Key('custom_interviewer_save_button'),
                onPressed: _savingCustomInterviewer ? null : _handleSaveCustomInterviewer,
                icon: _savingCustomInterviewer
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onTertiary))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Save & Select Persona'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FitCheckTheme.tertiary,
                  foregroundColor: FitCheckTheme.onTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
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
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.smart_toy_outlined, size: 48, color: FitCheckTheme.outline),
            SizedBox(height: 16),
            Text('No Interviewers Configured', style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: _fetchData, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildInterviewersGrid(bool isDesktop) {
    // Rank interviewers transparently using recommendation service
    final ranked = InterviewerRecommendationService.rankInterviewers(
      interviewers: _interviewers,
      job: _selectedJob,
      customJobTitle: _customJobTitleCtrl.text,
      customJobDescription: _customJobDescCtrl.text,
      candidate: widget.candidate,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 2 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 1.35 : 1.15,
      ),
      itemCount: ranked.length,
      itemBuilder: (context, i) {
        final rec = ranked[i];
        final interviewer = rec.interviewer;
        final isSelected = _selectedInterviewer?.id == interviewer.id;

        return Container(
          key: Key('interviewer_card_${interviewer.id}'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? FitCheckTheme.surfaceContainerHigh : FitCheckTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? FitCheckTheme.primary
                  : (rec.isTopMatch ? FitCheckTheme.tertiary.withValues(alpha: 0.6) : FitCheckTheme.outlineVariant),
              width: isSelected ? 2 : (rec.isTopMatch ? 1.5 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Persona Info + Voice Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected ? FitCheckTheme.primary.withValues(alpha: 0.15) : FitCheckTheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? FitCheckTheme.primary : FitCheckTheme.outlineVariant,
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: isSelected ? FitCheckTheme.primary : FitCheckTheme.secondary,
                                size: 24,
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
                                          interviewer.name,
                                          style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface)
                                              .copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 6),
                                        const Icon(Icons.check_circle, size: 16, color: FitCheckTheme.primary),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${interviewer.title} • ${interviewer.companyContext ?? "Tech Team"}',
                                    style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          interviewer.voiceDisplayName.toUpperCase(),
                          style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary).copyWith(fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Recommendation Badge & Rationale
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rec.isTopMatch
                          ? FitCheckTheme.tertiary.withValues(alpha: 0.15)
                          : FitCheckTheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          rec.isTopMatch ? Icons.star : Icons.info_outline,
                          size: 12,
                          color: rec.isTopMatch ? FitCheckTheme.tertiary : FitCheckTheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            rec.badgeText,
                            style: FitCheckTheme.labelSmall(
                              color: rec.isTopMatch ? FitCheckTheme.tertiary : FitCheckTheme.outline,
                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    interviewer.bio ?? 'Technical interviewer focused on architecture rigor and trade-offs.',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Focus areas chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: interviewer.focusAreas.take(3).map((area) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          area,
                          style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 10),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // Bottom Bar: Style + Action Button
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'STYLE: ${interviewer.questioningStyle.toUpperCase()}',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary),
                      ),
                    ),
                    ElevatedButton.icon(
                      key: Key('select_interviewer_${interviewer.id}'),
                      onPressed: () => _handleSelectInterviewer(interviewer),
                      icon: Icon(isSelected ? Icons.check : Icons.play_arrow, size: 14),
                      label: Text(isSelected ? 'Selected • Configure' : 'Select & Practice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? FitCheckTheme.primary : FitCheckTheme.surfaceContainerHighest,
                        foregroundColor: isSelected ? FitCheckTheme.onPrimary : FitCheckTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
