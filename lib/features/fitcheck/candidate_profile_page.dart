import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'fitcheck_api_service.dart';

class CandidateProfilePage extends StatefulWidget {
  final FitCheckApiService apiService;
  final Function(FitCheckCandidate candidate) onCandidateSelected;
  final FitCheckUser? currentUser;
  final VoidCallback? onSignOut;

  const CandidateProfilePage({
    super.key,
    required this.apiService,
    required this.onCandidateSelected,
    this.currentUser,
    this.onSignOut,
  });

  @override
  State<CandidateProfilePage> createState() => _CandidateProfilePageState();
}

class _CandidateProfilePageState extends State<CandidateProfilePage> {
  List<FitCheckCandidate> _candidates = [];
  bool _loading = false;
  String? _error;

  // New Candidate Form State
  bool _isCreating = false;
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _skillsController = TextEditingController();
  final _resumeTextController = TextEditingController();
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _fetchCandidates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _skillsController.dispose();
    _resumeTextController.dispose();
    super.dispose();
  }

  Future<void> _fetchCandidates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.apiService.listCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = list;
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

  Future<void> _extractFromResumeText() async {
    final text = _resumeTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste resume text to extract.')),
      );
      return;
    }
    setState(() => _extracting = true);
    try {
      final parsed = await widget.apiService.parseResumeText(text);
      if (!mounted) return;
      setState(() {
        _extracting = false;
        if (parsed['full_name'] != null && _nameController.text.isEmpty) {
          _nameController.text = parsed['full_name'] as String;
        }
        if (parsed['headline'] != null && _headlineController.text.isEmpty) {
          _headlineController.text = parsed['headline'] as String;
        }
        if (parsed['skills'] != null) {
          final skills = (parsed['skills'] as List<dynamic>).cast<String>();
          _skillsController.text = skills.join(', ');
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume extracted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _extracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extraction failed: $e')),
      );
    }
  }

  Future<void> _saveCandidate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Candidate name is required.')),
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
      final newCandidate = await widget.apiService.createCandidate({
        'full_name': name,
        'headline': _headlineController.text.trim(),
        'skills': skillsList,
        'raw_resume_text': _resumeTextController.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _candidates.insert(0, newCandidate);
        _isCreating = false;
        _loading = false;
      });
      widget.onCandidateSelected(newCandidate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating candidate: $e')),
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
        title: const Text('Candidate Context & Resume', style: TextStyle(color: FitCheckTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(_isCreating ? Icons.close : Icons.add, color: FitCheckTheme.primary),
            onPressed: () => setState(() => _isCreating = !_isCreating),
            tooltip: _isCreating ? 'Cancel' : 'New Candidate',
          ),
          if (widget.onSignOut != null)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              tooltip: widget.currentUser?.email != null
                  ? 'Sign Out (${widget.currentUser!.email})'
                  : 'Sign Out',
              onPressed: widget.onSignOut,
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

                  if (_isCreating) _buildCreateForm() else _buildCandidateList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateForm() {
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
            'Create or Ingest Candidate Profile',
            style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _resumeTextController,
            maxLines: 4,
            style: const TextStyle(color: FitCheckTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Paste plain text resume or work history...',
              hintStyle: const TextStyle(color: FitCheckTheme.textMuted),
              filled: true,
              fillColor: FitCheckTheme.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _extracting ? null : _extractFromResumeText,
              icon: _extracting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 16, color: FitCheckTheme.primary),
              label: Text(_extracting ? 'Extracting...' : 'AI Extract Details', style: const TextStyle(color: FitCheckTheme.primary, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FitCheckTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _headlineController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Professional Headline',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _skillsController,
            style: const TextStyle(color: FitCheckTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Key Skills (comma separated)',
              labelStyle: TextStyle(color: FitCheckTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveCandidate,
            style: ElevatedButton.styleFrom(
              backgroundColor: FitCheckTheme.primary,
              foregroundColor: FitCheckTheme.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save & Select Candidate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateList() {
    if (_candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.person_search_outlined, size: 48, color: FitCheckTheme.textMuted),
              const SizedBox(height: 12),
              const Text('No candidate profiles found.', style: TextStyle(color: FitCheckTheme.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => setState(() => _isCreating = true),
                icon: const Icon(Icons.add),
                label: const Text('Create Candidate Profile'),
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
          'Select Candidate for Interview',
          style: TextStyle(color: FitCheckTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._candidates.map((cand) {
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
                cand.fullName,
                style: const TextStyle(color: FitCheckTheme.textPrimary, fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cand.headline != null && cand.headline!.isNotEmpty)
                    Text(cand.headline!, style: const TextStyle(color: FitCheckTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: cand.skills.take(4).map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FitCheckTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(skill, style: const TextStyle(color: FitCheckTheme.primary, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FitCheckTheme.textMuted),
              onTap: () => widget.onCandidateSelected(cand),
            ),
          );
        }),
      ],
    );
  }
}

