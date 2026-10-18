import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/authenticated_api_client.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/theme/fitcheck_theme.dart';
import '../../call/call_session_manager.dart';
import '../fitcheck_api_service.dart';
import '../fitcheck_auth_page.dart';
import '../live_interview_room_page.dart';
import 'app_settings_page.dart';
import 'candidate_command_center_page.dart';
import 'candidate_profile_detail_page.dart';
import 'evaluation_scorecard_page.dart';
import 'hardware_readiness_page.dart';
import 'help_faq_page.dart';
import 'interview_history_page.dart';
import 'interviewer_library_page.dart';
import 'learning_plan_page.dart';
import 'notifications_page.dart';
import 'practice_library_page.dart';
import 'public_landing_page.dart';
import 'skill_analytics_page.dart';
import 'target_jobs_page.dart';

enum FitCheckRoute {
  landing,
  auth,
  commandCenter,
  hardwareSetup,
  liveStudio,
  scorecard,
  history,
  skillAnalytics,
  targetJobs,
  interviewerLibrary,
  practiceLibrary,
  learningPlan,
  candidateProfile,
  notifications,
  settings,
  helpFaq,
}

class FitCheckShell extends StatefulWidget {
  final AuthService? authService;
  final FitCheckApiService? apiService;
  final FitCheckRoute? initialRoute;

  const FitCheckShell({
    super.key,
    this.authService,
    this.apiService,
    this.initialRoute,
  });

  @override
  State<FitCheckShell> createState() => _FitCheckShellState();
}

class _FitCheckShellState extends State<FitCheckShell> {
  late FitCheckRoute _currentRoute;
  late final AuthService _authService;
  late final FitCheckApiService _apiService;
  StreamSubscription<FitCheckUser?>? _authSubscription;
  FitCheckUser? _demoUser;

  FitCheckCandidate? _candidateProfile;
  List<FitCheckSession> _sessions = [];
  List<FitCheckEvaluation> _evaluations = [];
  FitCheckSession? _activeSession;
  FitCheckEvaluation? _activeEvaluation;
  FitCheckInterviewer? _selectedInterviewer;
  FitCheckJob? _selectedJob;
  List<FitCheckInterviewer> _interviewers = [];
  List<FitCheckJob> _jobs = [];
  bool _loadingData = false;
  bool _isDemoMode = false;

  FitCheckApiService get apiService => _apiService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
    _apiService = widget.apiService ??
        FitCheckApiService(
          client: AuthenticatedApiClient(authService: _authService),
        );

    CallSessionManager.instance.onRestoreRoute = (ctx) {
      if (mounted) {
        _navigateTo(FitCheckRoute.liveStudio);
      }
    };

    if (widget.initialRoute != null) {
      _currentRoute = widget.initialRoute!;
    } else {
      _currentRoute = (_authService.currentUser != null)
          ? FitCheckRoute.commandCenter
          : FitCheckRoute.landing;
    }

    if (_authService.currentUser != null) {
      _isDemoMode = _authService.isDemoUser;
      _loadCandidateData();
    } else {
      _restoreDemoSessionIfAny();
    }

    _authSubscription = _authService.authStateChanges.listen((user) {
      if (!mounted) return;
      if (user == null &&
          _demoUser == null &&
          _currentRoute != FitCheckRoute.landing &&
          _currentRoute != FitCheckRoute.auth) {
        setState(() {
          _currentRoute = FitCheckRoute.landing;
          _candidateProfile = null;
          _sessions = [];
          _evaluations = [];
          _interviewers = [];
          _jobs = [];
          _selectedInterviewer = null;
          _selectedJob = null;
          _isDemoMode = false;
        });
      } else if (user != null) {
        _isDemoMode = _authService.isDemoUser;
        _loadCandidateData();
      }
    });
  }

  Future<void> _restoreDemoSessionIfAny() async {
    try {
      final restoredUser = await _authService.restoreDemoSession();
      if (restoredUser != null && mounted) {
        setState(() {
          _isDemoMode = true;
          if (_currentRoute == FitCheckRoute.landing) {
            _currentRoute = FitCheckRoute.commandCenter;
          }
        });
        await _loadCandidateData();
      }
    } catch (e) {
      debugPrint('[FitCheckShell] Error during demo session restore: $e');
    }
  }

  @override
  void dispose() {
    CallSessionManager.instance.onRestoreRoute = null;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCandidateData() async {
    final user = _authService.currentUser;
    if (user == null) return;
    setState(() => _loadingData = true);
    try {
      var candidate = await _apiService.getCurrentCandidate();
      candidate ??= await _apiService.createCandidate({
        'full_name': user.displayName ?? (user.email != null ? user.email!.split('@').first : 'Candidate'),
        'headline': 'Software Engineer Candidate',
        'skills': ['Distributed Systems', 'Architecture', 'Python', 'Go'],
      });
      final sessions = await _apiService.listSessions();
      final evals = await _apiService.listEvaluations();
      final interviewers = await _apiService.getInterviewers();
      final jobs = await _apiService.listJobs();
      if (!mounted) return;
      setState(() {
        _candidateProfile = candidate;
        _sessions = sessions;
        _evaluations = evals;
        _interviewers = interviewers;
        _jobs = jobs;
        if (_selectedInterviewer == null && interviewers.isNotEmpty) {
          _selectedInterviewer = interviewers.first;
        }
        if (_selectedJob == null && jobs.isNotEmpty) {
          _selectedJob = jobs.first;
        }
        _loadingData = false;
      });
    } catch (e) {
      debugPrint('[FitCheckShell] Error loading candidate data: $e');
      if (!mounted) return;
      if (_isDemoMode || _authService.isDemoUser) {
        setState(() {
          _candidateProfile ??= FitCheckCandidate(
            id: user.uid,
            fullName: user.displayName ?? 'Shinchan Nohara',
            headline: 'Aspiring Full Stack Engineer & SDE Candidate',
            skills: const ['Python', 'C++', 'Data Structures & Algorithms', 'AI Tools', 'Web Development'],
          );
          if (_interviewers.isEmpty) {
            _interviewers = [
              const FitCheckInterviewer(
                id: 'int-marcus-001',
                name: 'Marcus Vance',
                title: 'Lead System Security Engineer',
                companyContext: 'Fintech & Cloud Systems',
                questioningStyle: 'challenging',
                voiceId: 'Puck',
                isPreset: true,
              ),
              const FitCheckInterviewer(
                id: 'int-alex-001',
                name: 'Alex Rivera',
                title: 'Staff Distributed Systems Architect',
                companyContext: 'High-Scale Infrastructure',
                questioningStyle: 'rigorous',
                voiceId: 'Fenrir',
                isPreset: true,
              ),
            ];
          }
          _selectedInterviewer ??= _interviewers.first;
          _selectedJob ??= const FitCheckJob(
            id: 'job-default',
            title: 'Software Development Engineer',
            seniority: 'Mid-Level',
            description: 'Core software engineering role focusing on distributed systems and APIs.',
            requiredSkills: ['Python', 'Distributed Systems'],
            competencies: [],
          );
          _loadingData = false;
        });
        return;
      }
      setState(() => _loadingData = false);
    }
  }

  void _navigateTo(FitCheckRoute route) {
    if (_currentRoute == FitCheckRoute.liveStudio && route != FitCheckRoute.liveStudio) {
      if (CallSessionManager.instance.isCallActive) {
        CallSessionManager.instance.minimize();
      }
    }
    setState(() {
      _currentRoute = route;
    });
  }

  Future<void> _handleLaunchDrill(Map<String, dynamic> drill) async {
    final drillId = 'job-${drill['id']}';
    final competenciesList = ((drill['competencies'] as List<dynamic>?) ?? [])
        .map((c) => {
              'name': c.toString(),
              'criteria': [
                'Demonstrates deep architectural reasoning in $c',
                'Identifies boundary constraints and failure mitigation for $c',
              ],
            })
        .toList();

    final drillJob = FitCheckJob(
      id: drillId,
      title: 'Practice Drill: ${drill['title']}',
      seniority: drill['difficulty'] == 'EXPERT'
          ? 'Principal / Staff'
          : (drill['difficulty'] == 'HARD' ? 'Senior' : 'Mid-Level'),
      description: '${drill['description']} Focused scenario in ${drill['category']}.',
      requiredSkills: ((drill['competencies'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      competencies: competenciesList,
    );

    setState(() {
      _selectedJob = drillJob;
      final existingIdx = _jobs.indexWhere((j) => j.id == drillId);
      if (existingIdx >= 0) {
        _jobs[existingIdx] = drillJob;
      } else {
        _jobs.add(drillJob);
      }
    });

    if (!_isDemoMode) {
      try {
        await _apiService.createJob({
          'id': drillId,
          'title': drillJob.title,
          'seniority': drillJob.seniority,
          'description': drillJob.description,
          'required_skills': drillJob.requiredSkills,
          'competencies': drillJob.competencies,
        });
      } catch (e) {
        debugPrint('[FitCheckShell] Drill job creation note: $e');
      }
    }

    _navigateTo(FitCheckRoute.hardwareSetup);
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = _authService.currentUser ?? _demoUser;

    switch (_currentRoute) {
      case FitCheckRoute.landing:
        return PublicLandingPage(
          onTryDemo: () async {
            try {
              await _authService.signInAsDemo();
              _isDemoMode = true;
              await _loadCandidateData();
              _navigateTo(FitCheckRoute.commandCenter);
            } catch (e) {
              debugPrint('[FitCheckShell] Try Demo error: $e');
              _navigateTo(FitCheckRoute.auth);
            }
          },
          onStartPreparing: () {
            if (_authService.currentUser != null && !_isDemoMode) {
              _navigateTo(FitCheckRoute.commandCenter);
            } else {
              _navigateTo(FitCheckRoute.auth);
            }
          },
          onSignIn: () {
            if (activeUser != null) {
              _navigateTo(FitCheckRoute.commandCenter);
            } else {
              _navigateTo(FitCheckRoute.auth);
            }
          },
        );

      case FitCheckRoute.auth:
        return FitCheckAuthPage(
          authService: _authService,
          onBack: () => _navigateTo(FitCheckRoute.landing),
          onAuthenticated: () {
            if (_authService.currentUser == null) {
              _demoUser = const FitCheckUser(
                uid: 'cand-shinchan-demo',
                email: 'shinchan.demo@fitcheck.io',
                displayName: 'Shinchan Nohara',
              );
              _isDemoMode = true;
              _candidateProfile ??= const FitCheckCandidate(
                id: 'cand-shinchan-demo',
                fullName: 'Shinchan Nohara',
                headline: 'Aspiring Full Stack Engineer & SDE Candidate',
                skills: ['Python', 'C++', 'Data Structures & Algorithms', 'AI Tools', 'Web Development'],
              );
              _selectedInterviewer ??= const FitCheckInterviewer(
                id: 'int-marcus-001',
                name: 'Marcus Vance',
                title: 'Principal Distributed Systems Architect',
                companyContext: 'Stripe',
                questioningStyle: 'challenging',
                voiceId: 'Fenrir',
                isPreset: true,
              );
              _selectedJob ??= const FitCheckJob(
                id: 'job-dist-sys',
                title: 'Staff Distributed Systems Engineer',
                seniority: 'L6 / Staff',
                requiredSkills: ['Raft', 'Distributed Storage', 'Consensus', 'Python', 'Algorithms'],
                description: 'Calibrated hiring standard for systems architecture.',
              );
            } else {
              final isDemo = _authService.isDemoUser;
              _isDemoMode = isDemo;
              _loadCandidateData();
            }
            _navigateTo(FitCheckRoute.commandCenter);
          },
        );

      case FitCheckRoute.commandCenter:
        return CandidateCommandCenterPage(
          currentUser: activeUser,
          candidate: _candidateProfile,
          sessions: _sessions,
          evaluations: _evaluations,
          isDemoMode: _isDemoMode,
          apiService: _apiService,
          isLoading: _loadingData,
          onRefresh: _loadCandidateData,
          onStartFreshDemo: () async {
            try {
              await _authService.clearDemoSession();
              await _authService.signInAsDemo();
              _isDemoMode = true;
              await _loadCandidateData();
              _navigateTo(FitCheckRoute.commandCenter);
            } catch (e) {
              debugPrint('[FitCheckShell] Start fresh demo error: $e');
            }
          },
          onNavigate: _navigateTo,
          onProfileUpdated: (updated) {
            setState(() => _candidateProfile = updated);
          },
          onSelectSession: (sessionId) {
            final sess = _sessions.where((s) => s.id == sessionId).firstOrNull;
            final ev = _evaluations.where((e) => e.sessionId == sessionId).firstOrNull;
            setState(() {
              _activeSession = sess;
              _activeEvaluation = ev;
            });
            _navigateTo(FitCheckRoute.scorecard);
          },
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onHardwareSetup: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onViewScorecard: () => _navigateTo(FitCheckRoute.scorecard),
          onViewHistory: () => _navigateTo(FitCheckRoute.history),
          onViewLibrary: () => _navigateTo(FitCheckRoute.practiceLibrary),
          onBackToLanding: () => _navigateTo(FitCheckRoute.landing),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.hardwareSetup:
        return HardwareReadinessPage(
          candidate: _candidateProfile,
          apiService: _apiService,
          isDemoMode: _isDemoMode,
          interviewer: _selectedInterviewer,
          job: _selectedJob,
          availableInterviewers: _interviewers.isNotEmpty ? _interviewers : null,
          onInterviewerChanged: (interviewer) {
            setState(() => _selectedInterviewer = interviewer);
          },
          onChangeInterviewer: () => _navigateTo(FitCheckRoute.interviewerLibrary),
          onChangeJob: () => _navigateTo(FitCheckRoute.targetJobs),
          onSessionCreated: (sess) {
            setState(() {
              _activeSession = sess;
              _sessions.insert(0, sess);
            });
          },
          onEnterLiveRoom: () => _navigateTo(FitCheckRoute.liveStudio),
          onBackToDashboard: () => _navigateTo(FitCheckRoute.commandCenter),
        );

      case FitCheckRoute.liveStudio:
        if (_activeSession == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateTo(FitCheckRoute.hardwareSetup);
          });
          return const Scaffold(
            backgroundColor: FitCheckTheme.surface,
            body: Center(
              child: CircularProgressIndicator(color: FitCheckTheme.primary),
            ),
          );
        }

        FitCheckInterviewer interviewer;
        final matching = _interviewers.where((i) => i.id == _activeSession!.interviewerId).firstOrNull;
        if (matching != null) {
          interviewer = matching;
        } else if (_selectedInterviewer != null && _selectedInterviewer!.id == _activeSession!.interviewerId) {
          interviewer = _selectedInterviewer!;
        } else if (_activeSession!.interviewerId == 'sarah-em-001' || _activeSession!.interviewerId == 'int-sarah') {
          interviewer = const FitCheckInterviewer(
            id: 'sarah-em-001',
            name: 'Sarah Chen',
            title: 'Senior Engineering Manager',
            companyContext: 'Uber Core Infra',
            questioningStyle: 'rigorous',
            voiceId: 'Aoede',
            isPreset: true,
            bio: 'Senior Engineering Manager leading infrastructure reliability, cross-functional engineering excellence, and large-scale incident management.',
          );
        } else if (_activeSession!.interviewerId == 'alex-lead-001' || _activeSession!.interviewerId == 'int-alex') {
          interviewer = const FitCheckInterviewer(
            id: 'alex-lead-001',
            name: 'Alex Rivera',
            title: 'Staff Full-Stack Product Engineer',
            companyContext: 'Vercel / Next.js',
            questioningStyle: 'conversational',
            voiceId: 'Puck',
            isPreset: true,
            bio: 'Staff Full-Stack Product Engineer focusing on modern web architecture, end-to-end user experience, and low-latency API design.',
          );
        } else {
          interviewer = const FitCheckInterviewer(
            id: 'marcus-arch-001',
            name: 'Marcus Vance',
            title: 'Principal Distributed Systems Architect',
            companyContext: 'Stripe',
            questioningStyle: 'challenging',
            voiceId: 'Fenrir',
            isPreset: true,
            bio: 'Principal Systems Architect specializing in distributed consensus, fault-tolerant infrastructure, and high-throughput transaction pipelines.',
          );
        }

        return FitCheckLiveInterviewRoom(
          session: _activeSession!,
          interviewer: interviewer,
          candidate: _candidateProfile,
          apiService: _apiService,
          onInterviewEnded: (endedSession) async {
            final idx = _sessions.indexWhere((s) => s.id == endedSession.id);
            if (idx >= 0) {
              _sessions[idx] = endedSession;
            } else {
              _sessions.insert(0, endedSession);
            }
            _activeSession = endedSession;

            if (_isDemoMode) {
              final demoEval = FitCheckEvaluation(
                id: 'demo-eval-${endedSession.id}',
                sessionId: endedSession.id,
                overallScore: 88.0,
                overallRecommendation: 'Strong Hire • Level 6 Ready',
                summaryVerdict:
                    'Demonstrated deep understanding of distributed consensus, Raft log replication, and edge case mitigation during partition split-brain scenarios.',
                competencyScores: const [
                  {'competency': 'Distributed Consensus & Raft', 'score': 4.5, 'benchmark': 4.0},
                  {'competency': 'Network Partition Tolerance', 'score': 4.2, 'benchmark': 3.8},
                  {'competency': 'High-Throughput Storage', 'score': 4.0, 'benchmark': 3.7},
                ],
                observedStrengths: const [
                  'Immediately identified heartbeat timeouts as primary vector for leader election storms.',
                  'Articulated trade-offs between linearizable read leases and state machine quorum reads.',
                ],
                technicalGaps: const [
                  'Could have evaluated memory consumption profiles during sustained snapshot compaction.',
                ],
                preparationRecommendations: const [
                  'Review multi-raft shard group placement algorithms before on-site.',
                ],
              );
              if (mounted) {
                setState(() {
                  _activeEvaluation = demoEval;
                  _evaluations.insert(0, demoEval);
                });
              }
            } else {
              try {
                final ev = await _apiService.getEvaluation(endedSession.id);
                if (mounted) {
                  setState(() {
                    _activeEvaluation = ev;
                    final evIdx = _evaluations.indexWhere((e) => e.sessionId == endedSession.id);
                    if (evIdx >= 0) {
                      _evaluations[evIdx] = ev;
                    } else {
                      _evaluations.insert(0, ev);
                    }
                  });
                }
              } catch (e) {
                debugPrint('[FitCheckShell] Evaluation retrieval note: $e');
              }
            }

            if (mounted) {
              _navigateTo(FitCheckRoute.scorecard);
            }
          },
        );

      case FitCheckRoute.scorecard:
        return EvaluationScorecardPage(
          evaluation: _activeEvaluation ?? (_evaluations.isNotEmpty ? _evaluations.first : null),
          session: _activeSession ?? (_sessions.isNotEmpty ? _sessions.first : null),
          isDemoMode: _isDemoMode,
          onBackToDashboard: () => _navigateTo(FitCheckRoute.commandCenter),
          onRetakeSimulation: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onLaunchRecommendedDrill: () => _navigateTo(FitCheckRoute.practiceLibrary),
        );

      case FitCheckRoute.history:
        return InterviewHistoryPage(
          apiService: _apiService,
          candidate: _candidateProfile,
          currentUser: activeUser,
          isDemoMode: _isDemoMode,
          initialSessions: _sessions,
          initialEvaluations: _evaluations,
          onSelectSession: (session, eval) {
            setState(() {
              _activeSession = session;
              _activeEvaluation = eval;
            });
            _navigateTo(FitCheckRoute.scorecard);
          },
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onNavigate: _navigateTo,
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.skillAnalytics:
        return SkillAnalyticsPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          sessions: _sessions,
          evaluations: _evaluations,
          isDemoMode: _isDemoMode,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.targetJobs:
        return TargetJobsPage(
          apiService: _apiService,
          candidate: _candidateProfile,
          currentUser: activeUser,
          onSelectJob: (job) {
            setState(() {
              _selectedJob = job;
            });
          },
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.interviewerLibrary:
        return InterviewerLibraryPage(
          apiService: _apiService,
          candidate: _candidateProfile,
          currentUser: activeUser,
          selectedInterviewer: _selectedInterviewer,
          selectedJob: _selectedJob,
          initialInterviewers: _interviewers.isNotEmpty ? _interviewers : null,
          initialJobs: _jobs.isNotEmpty ? _jobs : null,
          onSelectInterviewer: (interviewer) {
            setState(() {
              _selectedInterviewer = interviewer;
            });
            _navigateTo(FitCheckRoute.hardwareSetup);
          },
          onSelectJob: (job) {
            setState(() {
              _selectedJob = job;
            });
          },
          onCustomJobCreated: (job) {
            setState(() {
              _selectedJob = job;
              _jobs.add(job);
            });
          },
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.practiceLibrary:
        return PracticeLibraryPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          evaluations: _evaluations,
          sessions: _sessions,
          isDemoMode: _isDemoMode,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onLaunchDrill: _handleLaunchDrill,
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.learningPlan:
        return LearningPlanPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          evaluations: _evaluations,
          sessions: _sessions,
          isDemoMode: _isDemoMode,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.candidateProfile:
        return CandidateProfileDetailPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          apiService: _apiService,
          onProfileUpdated: (updated) {
            setState(() => _candidateProfile = updated);
          },
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.notifications:
        return NotificationsPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          evaluations: _evaluations,
          sessions: _sessions,
          isDemoMode: _isDemoMode,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.settings:
        return AppSettingsPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          apiService: _apiService,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );

      case FitCheckRoute.helpFaq:
        return HelpFaqPage(
          candidate: _candidateProfile,
          currentUser: activeUser,
          onNavigate: _navigateTo,
          onStartInterview: () => _navigateTo(FitCheckRoute.hardwareSetup),
          onSignOut: _handleSignOut,
        );
    }
  }

  Future<void> _handleSignOut() async {
    _demoUser = null;
    _candidateProfile = null;
    _sessions = [];
    _evaluations = [];
    _interviewers = [];
    _jobs = [];
    _selectedInterviewer = null;
    _selectedJob = null;
    _isDemoMode = false;
    _navigateTo(FitCheckRoute.landing);
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('[FitCheckShell] Sign out notice: $e');
    }
  }
}
