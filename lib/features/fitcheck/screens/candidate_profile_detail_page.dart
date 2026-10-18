import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../../core/widgets/fitcheck_logo.dart';
import '../fitcheck_api_service.dart';
import '../widgets/candidate_sidebar.dart';
import 'fitcheck_shell.dart';

class CandidateProfileDetailPage extends StatefulWidget {
  final FitCheckCandidate? candidate;
  final FitCheckUser? currentUser;
  final FitCheckApiService? apiService;
  final ValueChanged<FitCheckCandidate>? onProfileUpdated;
  final ValueChanged<FitCheckRoute> onNavigate;
  final VoidCallback onStartInterview;
  final VoidCallback onSignOut;

  const CandidateProfileDetailPage({
    super.key,
    this.candidate,
    this.currentUser,
    this.apiService,
    this.onProfileUpdated,
    required this.onNavigate,
    required this.onStartInterview,
    required this.onSignOut,
  });

  @override
  State<CandidateProfileDetailPage> createState() => _CandidateProfileDetailPageState();
}

class _CandidateProfileDetailPageState extends State<CandidateProfileDetailPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _headlineController;
  late final TextEditingController _skillsController;
  late final TextEditingController _targetRoleController;
  final TextEditingController _resumeTextController = TextEditingController();
  final TextEditingController _resumeFilenameController = TextEditingController(text: 'resume.pdf');

  bool _saving = false;
  String? _statusMessage;
  bool _showResumeIngestion = false;
  bool _extractingResume = false;
  String? _resumeError;
  Map<String, dynamic>? _extractedResumePreview;
  int _selectedResumeInputTab = 0; // 0 = Paste Text/Markdown, 1 = Upload File

  // Uploaded Resume Document State
  Uint8List? _uploadedFileBytes;
  String? _uploadedFileName;
  int? _uploadedFileSize;

  List<Map<String, dynamic>> _workExperience = [];
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _education = [];

  static const int maxResumeBytes = 5 * 1024 * 1024; // 5 MB

  @override
  void initState() {
    super.initState();
    final defaultName = (widget.candidate?.fullName.isNotEmpty == true)
        ? widget.candidate!.fullName
        : (widget.currentUser?.displayName ??
            (widget.currentUser?.email != null ? widget.currentUser!.email!.split('@').first : 'Candidate'));
    final defaultHeadline = widget.candidate?.headline ?? '';
    final defaultSkills = (widget.candidate?.skills.isNotEmpty == true)
        ? widget.candidate!.skills.join(', ')
        : '';

    _nameController = TextEditingController(text: defaultName);
    _headlineController = TextEditingController(text: defaultHeadline);
    _skillsController = TextEditingController(text: defaultSkills);
    _targetRoleController = TextEditingController(text: '');

    _workExperience = widget.candidate?.workExperience != null
        ? List<Map<String, dynamic>>.from(widget.candidate!.workExperience)
        : [];
    _projects = widget.candidate?.projects != null
        ? List<Map<String, dynamic>>.from(widget.candidate!.projects)
        : [];
    _education = widget.candidate?.education != null
        ? List<Map<String, dynamic>>.from(widget.candidate!.education)
        : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _skillsController.dispose();
    _targetRoleController.dispose();
    _resumeTextController.dispose();
    _resumeFilenameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    final skillsList = _skillsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      if (widget.apiService != null && widget.candidate != null) {
        final updated = await widget.apiService!.updateCandidate(
          widget.candidate!.id,
          {
            'full_name': _nameController.text.trim(),
            'headline': _headlineController.text.trim(),
            'skills': skillsList,
            'work_experience': _workExperience,
            'projects': _projects,
            'education': _education,
          },
        );
        widget.onProfileUpdated?.call(updated);
      } else {
        final updated = FitCheckCandidate(
          id: widget.candidate?.id ?? 'cand-local',
          fullName: _nameController.text.trim(),
          headline: _headlineController.text.trim(),
          skills: skillsList,
          workExperience: _workExperience,
          projects: _projects,
          education: _education,
        );
        widget.onProfileUpdated?.call(updated);
      }

      if (mounted) {
        setState(() {
          _saving = false;
          _statusMessage = 'Candidate profile saved successfully.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _statusMessage = 'Profile updated locally: $e';
        });
      }
    }
  }

  Future<void> _handleExtractPastedResume() async {
    final text = _resumeTextController.text.trim();
    if (text.length < 10) {
      setState(() => _resumeError = 'Please paste at least 10 characters of resume text to extract skills.');
      return;
    }
    if (text.length > maxResumeBytes) {
      setState(() => _resumeError = 'Pasted resume text exceeds the 5MB size limit.');
      return;
    }

    setState(() {
      _extractingResume = true;
      _resumeError = null;
    });

    try {
      if (widget.apiService != null) {
        final result = await widget.apiService!.parseResumeText(text, filename: 'pasted_resume.txt');
        if (!mounted) return;
        setState(() {
          _extractedResumePreview = result;
          _extractingResume = false;
        });
      } else {
        throw Exception('API service unavailable.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractingResume = false;
        _resumeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _handlePickResumeFile() async {
    setState(() => _resumeError = null);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );

      if (files.isEmpty) {
        return;
      }

      final file = files.first;
      final name = file.name;
      final ext = file.extension?.toLowerCase() ?? (name.contains('.') ? name.split('.').last.toLowerCase() : '');

      if (!['pdf', 'docx', 'txt'].contains(ext)) {
        setState(() => _resumeError = 'Unsupported format ($ext). Only PDF (.pdf), Word (.docx), and plain text (.txt) files are supported.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _resumeError = 'Could not read document contents. Please select a valid local file.');
        return;
      }

      if (bytes.length > maxResumeBytes) {
        final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        setState(() => _resumeError = 'Selected file is $mb MB, which exceeds the 5 MB maximum file limit.');
        return;
      }

      setState(() {
        _uploadedFileBytes = bytes;
        _uploadedFileName = name;
        _uploadedFileSize = bytes.length;
        _resumeError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resumeError = 'Error selecting file: $e');
    }
  }

  Future<void> _handleExtractUploadedFile() async {
    if (_uploadedFileBytes == null || _uploadedFileName == null) {
      setState(() => _resumeError = 'Please select a resume file (.pdf, .docx, or .txt) first.');
      return;
    }

    setState(() {
      _extractingResume = true;
      _resumeError = null;
    });

    try {
      if (widget.apiService != null) {
        final result = await widget.apiService!.uploadResume(
          fileBytes: _uploadedFileBytes!,
          filename: _uploadedFileName!,
          candidateId: widget.candidate?.id,
        );
        if (!mounted) return;
        setState(() {
          _extractedResumePreview = result;
          _extractingResume = false;
        });
      } else {
        throw Exception('API service unavailable.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extractingResume = false;
        _resumeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleApplyExtractedResume() {
    final preview = _extractedResumePreview;
    if (preview == null) return;

    if (preview['full_name'] != null && (preview['full_name'] as String).isNotEmpty) {
      _nameController.text = preview['full_name'] as String;
    }
    if (preview['headline'] != null && (preview['headline'] as String).isNotEmpty) {
      _headlineController.text = preview['headline'] as String;
    }
    if (preview['skills'] is List && (preview['skills'] as List).isNotEmpty) {
      final newSkills = (preview['skills'] as List).cast<String>();
      final existingSkills = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final merged = {...existingSkills, ...newSkills}.toList();
      _skillsController.text = merged.join(', ');
    }

    if (preview['work_experience'] is List) {
      _workExperience = (preview['work_experience'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (preview['projects'] is List) {
      _projects = (preview['projects'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (preview['education'] is List) {
      _education = (preview['education'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    _saveProfile();

    setState(() {
      _showResumeIngestion = false;
      _extractedResumePreview = null;
      _statusMessage = 'Extracted resume data applied and saved to candidate profile.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extracted resume details applied and saved to candidate profile.'),
        backgroundColor: FitCheckTheme.tertiary,
      ),
    );
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
              currentRoute: FitCheckRoute.candidateProfile,
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
                          const SizedBox(height: 20),
                          if (_showResumeIngestion) ...[
                            _buildResumeIngestionCard(),
                            const SizedBox(height: 20),
                          ],
                          if (_statusMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, size: 16, color: FitCheckTheme.tertiary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _statusMessage!,
                                    style: const TextStyle(color: FitCheckTheme.tertiary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _buildFormCard(),
                          if (_workExperience.isNotEmpty || _projects.isNotEmpty || _education.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildStructuredResumeDataCard(),
                          ],
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
              const FitCheckLogo(size: 16),
              const SizedBox(width: 8),
              Text('CANDIDATE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 14, color: FitCheckTheme.outline),
              const SizedBox(width: 8),
              Text('Profile & Competency Baseline', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface)),
            ],
          ),
          ElevatedButton.icon(
            key: const Key('save_profile_header_btn'),
            onPressed: _saving ? null : _saveProfile,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary),
                  )
                : const Icon(Icons.check, size: 14),
            label: Text(_saving ? 'Saving...' : 'Save Changes'),
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
            Text('Candidate Profile', style: FitCheckTheme.headlineMedium()),
            const SizedBox(height: 6),
            Text(
              'Manage your baseline skills and engineering background to calibrate simulation interviews.',
              style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurfaceVariant),
            ),
          ],
        ),
        OutlinedButton.icon(
          key: const Key('toggle_resume_ingestion_btn'),
          onPressed: () => setState(() => _showResumeIngestion = !_showResumeIngestion),
          icon: Icon(_showResumeIngestion ? Icons.expand_less : Icons.upload_file, size: 16),
          label: Text(_showResumeIngestion ? 'Hide Resume Ingestion' : 'Ingest Resume via AI'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FitCheckTheme.primary,
            side: const BorderSide(color: FitCheckTheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeIngestionCard() {
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
              const Icon(Icons.document_scanner_outlined, color: FitCheckTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'RESUME INGESTION & SKILL EXTRACTION (AI-POWERED)',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.primary).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload a PDF/text resume or paste raw text. FitCheck automatically extracts your verified skills, experience timeline, and engineering projects while preserving your privacy.',
            style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: FitCheckTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Supported Formats: .pdf, .txt, .text, .md • Maximum file size: 5 MB',
              style: TextStyle(color: FitCheckTheme.outline, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Paste Resume Text / Markdown'),
                selected: _selectedResumeInputTab == 0,
                onSelected: (sel) {
                  if (sel) setState(() => _selectedResumeInputTab = 0);
                },
                selectedColor: FitCheckTheme.primary.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Upload Document (.pdf, .txt, .md)'),
                selected: _selectedResumeInputTab == 1,
                onSelected: (sel) {
                  if (sel) setState(() => _selectedResumeInputTab = 1);
                },
                selectedColor: FitCheckTheme.primary.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_selectedResumeInputTab == 0) ...[
            TextField(
              key: const Key('parse_resume_text_input'),
              controller: _resumeTextController,
              maxLines: 6,
              style: const TextStyle(fontSize: 13, color: FitCheckTheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Paste resume contents, markdown experience, or LinkedIn text summary here...\n\ne.g.\nStaff Distributed Systems Architect\nExperience: 8+ years with Go, Raft, Kafka, Cassandra\nProjects: Multi-region distributed lock manager',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: FitCheckTheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  key: const Key('parse_resume_text_btn'),
                  onPressed: _extractingResume ? null : _handleExtractPastedResume,
                  icon: _extractingResume
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_extractingResume ? 'Extracting Resume Structure...' : 'Extract Profile via AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FitCheckTheme.primary,
                    foregroundColor: FitCheckTheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
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
                      Row(
                        children: [
                          const Icon(Icons.upload_file, size: 20, color: FitCheckTheme.primary),
                          const SizedBox(width: 8),
                          Text('Upload PDF or Word Document', style: FitCheckTheme.titleMedium(color: FitCheckTheme.onSurface)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('MAX 5 MB • PDF / DOCX / TXT', style: TextStyle(color: FitCheckTheme.outline, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your resume document to automatically extract work experience, core competencies, education, and target technical roles using Gemini.',
                    style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (_uploadedFileBytes == null) ...[
                    InkWell(
                      key: const Key('pick_resume_file_btn'),
                      onTap: _extractingResume ? null : _handlePickResumeFile,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: FitCheckTheme.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 36, color: FitCheckTheme.primary),
                            const SizedBox(height: 10),
                            const Text('Click to choose your resume file', style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Supports PDF (.pdf), Microsoft Word (.docx), and text (.txt)', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: FitCheckTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.description, color: FitCheckTheme.tertiary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedFileName ?? 'Selected Document',
                                  style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _uploadedFileSize != null
                                      ? '${(_uploadedFileSize! / 1024).toStringAsFixed(1)} KB'
                                      : 'Ready for ingestion',
                                  style: const TextStyle(color: FitCheckTheme.outline, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _extractingResume ? null : _handlePickResumeFile,
                            child: const Text('Change', style: TextStyle(color: FitCheckTheme.outline, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      key: const Key('extract_resume_file_btn'),
                      onPressed: _extractingResume ? null : _handleExtractUploadedFile,
                      icon: _extractingResume
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: FitCheckTheme.onPrimary),
                            )
                          : const Icon(Icons.auto_awesome, size: 14),
                      label: Text(_extractingResume ? 'Extracting via AI...' : 'Extract Profile from Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FitCheckTheme.primary,
                        foregroundColor: FitCheckTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_resumeError != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FitCheckTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: FitCheckTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: FitCheckTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_resumeError!, style: const TextStyle(color: FitCheckTheme.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          if (_extractedResumePreview != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FitCheckTheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FitCheckTheme.tertiary.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.preview_outlined, color: FitCheckTheme.tertiary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'EXTRACTED RESUME REVIEW (VERIFY BEFORE SAVING)',
                        style: FitCheckTheme.labelSmall(color: FitCheckTheme.tertiary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_extractedResumePreview!['full_name'] != null)
                    Text('Candidate: ${_extractedResumePreview!['full_name']}', style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold)),
                  if (_extractedResumePreview!['headline'] != null)
                    Text('Headline: ${_extractedResumePreview!['headline']}', style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
                  if (_extractedResumePreview!['skills'] is List) ...[
                    const SizedBox(height: 10),
                    Text('EXTRACTED SKILLS:', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final sk in (_extractedResumePreview!['skills'] as List))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FitCheckTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(sk.toString(), style: const TextStyle(color: FitCheckTheme.primary, fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                  if (_extractedResumePreview!['work_experience'] is List && (_extractedResumePreview!['work_experience'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('WORK EXPERIENCE:', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
                    const SizedBox(height: 4),
                    for (final exp in (_extractedResumePreview!['work_experience'] as List))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${exp['role']} @ ${exp['company']}${exp['description'] != null ? ' — ${exp['description']}' : ''}',
                          style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        key: const Key('apply_extracted_resume_btn'),
                        onPressed: _handleApplyExtractedResume,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Apply Extracted Profile & Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FitCheckTheme.tertiary,
                          foregroundColor: FitCheckTheme.onTertiary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => setState(() => _extractedResumePreview = null),
                        child: const Text('Discard Preview', style: TextStyle(color: FitCheckTheme.outline)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStructuredResumeDataCard() {
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
            children: [
              const Icon(Icons.work_history_outlined, color: FitCheckTheme.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                'STRUCTURED EXPERIENCE & BACKGROUND TIMELINE',
                style: FitCheckTheme.labelSmall(color: FitCheckTheme.secondary).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_workExperience.isNotEmpty) ...[
            Text('WORK EXPERIENCE', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            const SizedBox(height: 8),
            for (final w in _workExperience)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${w['role']} @ ${w['company']}',
                      style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (w['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(w['description'].toString(), style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
          ],
          if (_projects.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('ENGINEERING PROJECTS', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            const SizedBox(height: 8),
            for (final p in _projects)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name']?.toString() ?? 'Project',
                      style: FitCheckTheme.bodyMedium(color: FitCheckTheme.onSurface).copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (p['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(p['description'].toString(), style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
          ],
          if (_education.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('EDUCATION & DEGREES', style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline)),
            const SizedBox(height: 8),
            for (final ed in _education)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitCheckTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: FitCheckTheme.outlineVariant),
                ),
                child: Text(
                  '${ed['degree'] ?? ''} in ${ed['field_of_study'] ?? ''} • ${ed['institution'] ?? ''}',
                  style: FitCheckTheme.bodySmall(color: FitCheckTheme.onSurface),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormCard() {
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
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: FitCheckTheme.surfaceContainerHighest,
                child: Text(
                  _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'C',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: FitCheckTheme.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameController.text, style: FitCheckTheme.titleMedium()),
                    const SizedBox(height: 2),
                    Text(
                      widget.currentUser?.email ?? 'candidate@fitcheck.io',
                      style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: FitCheckTheme.outlineVariant),
          const SizedBox(height: 24),
          _buildField(
            keyName: 'profile_name_input',
            label: 'FULL NAME',
            controller: _nameController,
            hint: 'e.g. Elena Rostova',
          ),
          const SizedBox(height: 20),
          _buildField(
            keyName: 'profile_headline_input',
            label: 'HEADLINE / CURRENT ROLE',
            controller: _headlineController,
            hint: 'e.g. Staff Systems Engineer @ Stripe',
          ),
          const SizedBox(height: 20),
          _buildField(
            keyName: 'profile_target_role_input',
            label: 'TARGET BENCHMARK ROLE',
            controller: _targetRoleController,
            hint: 'e.g. Principal Distributed Systems Engineer',
          ),
          const SizedBox(height: 20),
          _buildField(
            keyName: 'profile_skills_input',
            label: 'VERIFIED SKILLS (COMMA SEPARATED)',
            controller: _skillsController,
            hint: 'e.g. Go, Distributed Systems, Raft, Kubernetes',
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('save_profile_submit_btn'),
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: FitCheckTheme.primary,
                foregroundColor: FitCheckTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(_saving ? 'Saving Changes...' : 'Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String keyName,
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FitCheckTheme.labelSmall(color: FitCheckTheme.outline).copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        TextField(
          key: Key(keyName),
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: FitCheckTheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: FitCheckTheme.outline),
            filled: true,
            fillColor: FitCheckTheme.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: FitCheckTheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: FitCheckTheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: FitCheckTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
