import 'dart:convert';
import '../../core/api/authenticated_api_client.dart';
import '../../core/auth/auth_service.dart';

class FitCheckCandidate {
  final String id;
  final String fullName;
  final String? headline;
  final List<String> skills;
  final List<Map<String, dynamic>> workExperience;
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> education;

  const FitCheckCandidate({
    required this.id,
    required this.fullName,
    this.headline,
    this.skills = const [],
    this.workExperience = const [],
    this.projects = const [],
    this.education = const [],
  });

  factory FitCheckCandidate.fromJson(Map<String, dynamic> json) {
    return FitCheckCandidate(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Candidate',
      headline: json['headline'] as String?,
      skills: (json['skills'] as List<dynamic>?)?.cast<String>() ?? [],
      workExperience: (json['work_experience'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      projects: (json['projects'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      education: (json['education'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'headline': headline,
      'skills': skills,
      'work_experience': workExperience,
      'projects': projects,
      'education': education,
    };
  }

  FitCheckCandidate copyWith({
    String? id,
    String? fullName,
    String? headline,
    List<String>? skills,
    List<Map<String, dynamic>>? workExperience,
    List<Map<String, dynamic>>? projects,
    List<Map<String, dynamic>>? education,
  }) {
    return FitCheckCandidate(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      headline: headline ?? this.headline,
      skills: skills ?? this.skills,
      workExperience: workExperience ?? this.workExperience,
      projects: projects ?? this.projects,
      education: education ?? this.education,
    );
  }
}

class FitCheckJob {
  final String id;
  final String title;
  final String seniority;
  final String description;
  final List<String> requiredSkills;
  final List<Map<String, dynamic>> competencies;

  const FitCheckJob({
    required this.id,
    required this.title,
    required this.seniority,
    required this.description,
    this.requiredSkills = const [],
    this.competencies = const [],
  });

  factory FitCheckJob.fromJson(Map<String, dynamic> json) {
    return FitCheckJob(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Software Engineer',
      seniority: json['seniority'] as String? ?? 'senior',
      description: json['description'] as String? ?? '',
      requiredSkills: (json['required_skills'] as List<dynamic>?)?.cast<String>() ?? [],
      competencies: (json['competencies'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}

class FitCheckInterviewer {
  final String id;
  final String name;
  final String title;
  final String? companyContext;
  final String questioningStyle;
  final String voiceId;
  final bool isPreset;
  final String? bio;
  final Map<String, dynamic>? provenance;

  const FitCheckInterviewer({
    required this.id,
    required this.name,
    required this.title,
    this.companyContext,
    required this.questioningStyle,
    required this.voiceId,
    this.isPreset = false,
    this.bio,
    this.provenance,
  });

  factory FitCheckInterviewer.fromJson(Map<String, dynamic> json) {
    return FitCheckInterviewer(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Interviewer',
      title: json['title'] as String? ?? 'Senior Engineer',
      companyContext: json['company_context'] as String?,
      questioningStyle: json['questioning_style'] as String? ?? 'conversational',
      voiceId: json['voice_id'] as String? ?? 'Puck',
      isPreset: json['is_preset'] as bool? ?? false,
      bio: json['bio'] as String?,
      provenance: json['provenance'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'company_context': companyContext,
      'questioning_style': questioningStyle,
      'voice_id': voiceId,
      'is_preset': isPreset,
      'bio': bio,
      'provenance': provenance,
    };
  }

  List<String> get focusAreas {
    if (provenance != null && provenance!['inferred_style'] is Map) {
      final style = provenance!['inferred_style'] as Map;
      if (style['focus_areas'] is List) {
        return (style['focus_areas'] as List).cast<String>();
      }
    }
    // Fallback extraction from persona identity
    if (name.contains('Marcus')) {
      return const [
        'Distributed Consensus & Raft',
        'Concurrency & Race Conditions',
        'Database Sharding & Partitioning',
        'Fault Isolation & Disaster Recovery',
      ];
    }
    if (name.contains('Sarah')) {
      return const [
        'Engineering Leadership & Velocity',
        'Cloud Platform Reliability',
        'Incident Response & Postmortems',
        'Cross-Functional Strategy',
      ];
    }
    if (name.contains('Alex')) {
      return const [
        'Full-Stack Architecture & APIs',
        'Modern Web & Product Execution',
        'Developer Experience & Clean Code',
        'Latency & Frontend Optimization',
      ];
    }
    return const ['System Architecture', 'Technical Trade-offs'];
  }

  String get specialty {
    if (focusAreas.isNotEmpty) {
      return focusAreas.first;
    }
    return 'Technical Architecture';
  }

  String get voiceDisplayName {
    switch (voiceId.toLowerCase()) {
      case 'aoede':
        return 'Aoede (Warm • Calibrated Female)';
      case 'fenrir':
        return 'Fenrir (Deep • Authoritative Male)';
      case 'puck':
        return 'Puck (Conversational • Direct)';
      case 'charon':
        return 'Charon (Deep • Analytical Male)';
      case 'kore':
        return 'Kore (Relaxed • Conversational Female)';
      default:
        return '$voiceId (Gemini Live Standard)';
    }
  }

  String get behavioralDirective {
    switch (questioningStyle.toLowerCase()) {
      case 'challenging':
      case 'deep_probing':
        return '$name probes deeply into concurrency bottlenecks, edge-case recovery, and latency trade-offs. Avoid hand-wavy claims; quantify exact constraints and failure modes.';
      case 'rigorous':
        return '$name focuses on operational resilience, incident mitigation, and ownership. Expect systematic evaluation of engineering velocity, production risks, and trade-offs.';
      case 'conversational':
      default:
        return '$name evaluates pragmatic product architecture, clean code structure, and user impact. Expect collaborative discussion on modern frameworks, API boundaries, and execution speed.';
    }
  }

  FitCheckInterviewer copyWith({
    String? id,
    String? name,
    String? title,
    String? companyContext,
    String? questioningStyle,
    String? voiceId,
    bool? isPreset,
    String? bio,
    Map<String, dynamic>? provenance,
  }) {
    return FitCheckInterviewer(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      companyContext: companyContext ?? this.companyContext,
      questioningStyle: questioningStyle ?? this.questioningStyle,
      voiceId: voiceId ?? this.voiceId,
      isPreset: isPreset ?? this.isPreset,
      bio: bio ?? this.bio,
      provenance: provenance ?? this.provenance,
    );
  }
}

class FitCheckSession {
  final String id;
  final String candidateId;
  final String jobId;
  final String interviewerId;
  final String difficulty;
  final String status;
  final String channel;
  final String? agentId;
  final Map<String, dynamic>? sessionPlan;
  final String? rtcToken;
  final String? appId;
  final List<dynamic>? transcript;
  final String startedAt;
  final String? endedAt;

  const FitCheckSession({
    required this.id,
    required this.candidateId,
    required this.jobId,
    required this.interviewerId,
    required this.difficulty,
    required this.status,
    required this.channel,
    this.agentId,
    this.sessionPlan,
    this.rtcToken,
    this.appId,
    this.transcript,
    required this.startedAt,
    this.endedAt,
  });

  factory FitCheckSession.fromJson(Map<String, dynamic> json) {
    return FitCheckSession(
      id: json['id'] as String,
      candidateId: json['candidate_id'] as String,
      jobId: json['job_id'] as String,
      interviewerId: json['interviewer_id'] as String,
      difficulty: json['difficulty'] as String? ?? 'realistic',
      status: json['status'] as String? ?? 'active',
      channel: json['channel'] as String? ?? '',
      agentId: json['agent_id'] as String?,
      sessionPlan: json['session_plan'] as Map<String, dynamic>?,
      rtcToken: json['rtc_token'] as String?,
      appId: json['app_id'] as String?,
      transcript: json['transcript'] as List<dynamic>?,
      startedAt: json['started_at']?.toString() ?? '',
      endedAt: json['ended_at']?.toString(),
    );
  }
}

class FitCheckEvaluation {
  final String id;
  final String sessionId;
  final double overallScore;
  final String overallRecommendation;
  final String summaryVerdict;
  final List<Map<String, dynamic>> competencyScores;
  final List<String> observedStrengths;
  final List<String> technicalGaps;
  final List<String> preparationRecommendations;
  final Map<String, dynamic>? humanReview;
  final String? createdAt;

  const FitCheckEvaluation({
    required this.id,
    required this.sessionId,
    required this.overallScore,
    required this.overallRecommendation,
    required this.summaryVerdict,
    this.competencyScores = const [],
    this.observedStrengths = const [],
    this.technicalGaps = const [],
    this.preparationRecommendations = const [],
    this.humanReview,
    this.createdAt,
  });

  factory FitCheckEvaluation.fromJson(Map<String, dynamic> json) {
    return FitCheckEvaluation(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 3.0,
      overallRecommendation: json['overall_recommendation'] as String? ?? 'Under Review',
      summaryVerdict: json['summary_verdict'] as String? ?? '',
      competencyScores: (json['competency_scores'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      observedStrengths: (json['observed_strengths'] as List<dynamic>?)?.cast<String>() ?? [],
      technicalGaps: (json['technical_gaps'] as List<dynamic>?)?.cast<String>() ?? [],
      preparationRecommendations:
          (json['preparation_recommendations'] as List<dynamic>?)?.cast<String>() ?? [],
      humanReview: json['human_review'] as Map<String, dynamic>?,
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// Service wrapping FitCheck REST endpoints using the authenticated API client.
class FitCheckApiService {
  final AuthenticatedApiClient client;

  FitCheckApiService({AuthenticatedApiClient? client, AuthService? authService})
      : client = client ?? AuthenticatedApiClient(authService: authService ?? FirebaseAuthService());

  // Candidate Endpoints
  Future<List<FitCheckCandidate>> listCandidates() async {
    final resp = await client.get('/api/v1/candidates');
    if (resp.statusCode != 200) throw Exception('Failed to list candidates: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckCandidate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FitCheckCandidate?> getCurrentCandidate() async {
    try {
      final list = await listCandidates();
      if (list.isNotEmpty) return list.first;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<FitCheckCandidate> getCandidate(String candidateId) async {
    final resp = await client.get('/api/v1/candidates/$candidateId');
    if (resp.statusCode != 200) throw Exception('Failed to get candidate: ${resp.body}');
    return FitCheckCandidate.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<FitCheckCandidate> createCandidate(Map<String, dynamic> data) async {
    final resp = await client.post('/api/v1/candidates', body: data);
    if (resp.statusCode != 201) throw Exception('Failed to create candidate: ${resp.body}');
    return FitCheckCandidate.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<FitCheckCandidate> updateCandidate(String candidateId, Map<String, dynamic> data) async {
    final resp = await client.put('/api/v1/candidates/$candidateId', body: data);
    if (resp.statusCode != 200) throw Exception('Failed to update candidate: ${resp.body}');
    return FitCheckCandidate.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> deleteCandidate(String candidateId) async {
    final resp = await client.delete('/api/v1/candidates/$candidateId');
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('Failed to delete candidate: ${resp.body}');
    }
  }

  Future<Map<String, dynamic>> parseResumeText(String text, {String filename = 'pasted_resume.txt'}) async {
    final resp = await client.post(
      '/api/v1/candidates/parse-text',
      body: {
        'text': text,
        'filename': filename,
      },
    );
    if (resp.statusCode != 200) throw Exception('Failed to extract resume text: ${resp.body}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadResume({
    required List<int> fileBytes,
    required String filename,
    String? candidateId,
  }) async {
    final path = candidateId != null
        ? '/api/v1/candidates/$candidateId/upload-resume'
        : '/api/v1/candidates/upload-resume';
    final resp = await client.postMultipart(
      path,
      fileField: 'file',
      fileBytes: fileBytes,
      filename: filename,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to upload and extract resume: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // Job Endpoints
  Future<List<FitCheckJob>> listJobs() async {
    final resp = await client.get('/api/v1/jobs');
    if (resp.statusCode != 200) throw Exception('Failed to list jobs: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckJob.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FitCheckJob> createJob(Map<String, dynamic> data) async {
    final resp = await client.post('/api/v1/jobs', body: data);
    if (resp.statusCode != 201) throw Exception('Failed to create job: ${resp.body}');
    return FitCheckJob.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<FitCheckJob> updateJob(String jobId, Map<String, dynamic> data) async {
    final resp = await client.put('/api/v1/jobs/$jobId', body: data);
    if (resp.statusCode != 200) throw Exception('Failed to update job: ${resp.body}');
    return FitCheckJob.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> generateRubric({
    required String title,
    required String description,
    String seniority = 'senior',
    List<String> requiredSkills = const [],
  }) async {
    final resp = await client.post(
      '/api/v1/jobs/generate-rubric',
      body: {
        'title': title,
        'description': description,
        'seniority': seniority,
        'required_skills': requiredSkills,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to generate competency rubric: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final comps = data['competencies'] as List<dynamic>? ?? [];
    return comps.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Interviewer Endpoints
  Future<List<FitCheckInterviewer>> listInterviewers() async {
    final resp = await client.get('/api/v1/interviewers');
    if (resp.statusCode != 200) throw Exception('Failed to list interviewers: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckInterviewer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FitCheckInterviewer>> getInterviewers() => listInterviewers();

  Future<FitCheckInterviewer> getInterviewer(String interviewerId) async {
    final resp = await client.get('/api/v1/interviewers/$interviewerId');
    if (resp.statusCode != 200) throw Exception('Failed to get interviewer: ${resp.body}');
    return FitCheckInterviewer.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> personalizeInterviewer(Map<String, dynamic> data) async {
    final resp = await client.post('/api/v1/interviewers/personalize', body: data);
    if (resp.statusCode != 200) throw Exception('Failed to personalize interviewer: ${resp.body}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<FitCheckInterviewer> createInterviewer(Map<String, dynamic> data) async {
    final resp = await client.post('/api/v1/interviewers', body: data);
    if (resp.statusCode != 201) throw Exception('Failed to create interviewer: ${resp.body}');
    return FitCheckInterviewer.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // Session & Runtime Endpoints
  Future<FitCheckSession> startSession({
    required String candidateId,
    required String jobId,
    required String interviewerId,
    String difficulty = 'realistic',
  }) async {
    final resp = await client.post(
      '/api/v1/sessions',
      body: {
        'candidate_id': candidateId,
        'job_id': jobId,
        'interviewer_id': interviewerId,
        'difficulty': difficulty,
      },
    );
    if (resp.statusCode != 201) throw Exception('Failed to start session: ${resp.body}');
    return FitCheckSession.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getSessionPlan(String sessionId) async {
    final resp = await client.get('/api/v1/sessions/$sessionId/plan');
    if (resp.statusCode != 200) throw Exception('Failed to get session plan: ${resp.body}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getNextAdaptiveQuestion(String sessionId) async {
    final resp = await client.post('/api/v1/sessions/$sessionId/next-question');
    if (resp.statusCode != 200) throw Exception('Failed to get next question: ${resp.body}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<FitCheckSession> endSession(String sessionId, {List<Map<String, dynamic>> transcript = const []}) async {
    final resp = await client.post(
      '/api/v1/sessions/$sessionId/end',
      body: {'transcript': transcript},
    );
    if (resp.statusCode != 200) throw Exception('Failed to end session: ${resp.body}');
    return FitCheckSession.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<FitCheckEvaluation> getEvaluation(String sessionId) async {
    final resp = await client.get('/api/v1/evaluations/$sessionId');
    if (resp.statusCode != 200) throw Exception('Failed to get evaluation: ${resp.body}');
    return FitCheckEvaluation.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<FitCheckEvaluation>> listEvaluations() async {
    final resp = await client.get('/api/v1/evaluations');
    if (resp.statusCode != 200) throw Exception('Failed to list evaluations: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckEvaluation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FitCheckSession>> listSessions() async {
    final resp = await client.get('/api/v1/sessions');
    if (resp.statusCode != 200) throw Exception('Failed to list sessions: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckSession.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FitCheckCandidateMemory>> getCandidateMemories() async {
    final resp = await client.get('/api/v1/candidate/memories');
    if (resp.statusCode != 200) throw Exception('Failed to get candidate memories: ${resp.body}');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => FitCheckCandidateMemory.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteCandidateMemory(String memoryId) async {
    final resp = await client.delete('/api/v1/candidate/memories/$memoryId');
    if (resp.statusCode != 200) throw Exception('Failed to delete candidate memory: ${resp.body}');
  }

  Future<int> clearCandidateMemories() async {
    final resp = await client.delete('/api/v1/candidate/memories');
    if (resp.statusCode != 200) throw Exception('Failed to clear candidate memories: ${resp.body}');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['deleted_count'] as int? ?? 0;
  }
}

class FitCheckCandidateMemory {
  final String id;
  final String content;
  final String category;
  final double importance;
  final String? createdAt;

  const FitCheckCandidateMemory({
    required this.id,
    required this.content,
    required this.category,
    required this.importance,
    this.createdAt,
  });

  factory FitCheckCandidateMemory.fromJson(Map<String, dynamic> json) {
    return FitCheckCandidateMemory(
      id: json['id'] as String,
      content: json['content'] as String,
      category: json['category'] as String,
      importance: (json['importance'] as num).toDouble(),
      createdAt: json['created_at'] as String?,
    );
  }
}


