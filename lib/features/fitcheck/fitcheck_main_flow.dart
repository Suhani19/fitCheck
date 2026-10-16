import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/fitcheck_theme.dart';
import 'candidate_profile_page.dart';
import 'difficulty_selection_page.dart';
import 'fitcheck_api_service.dart';
import 'fitcheck_auth_page.dart';
import 'fitcheck_evaluation_page.dart';
import 'fitcheck_history_page.dart';
import 'interviewer_selection_page.dart';
import 'job_selection_page.dart';
import 'live_interview_room_page.dart';

enum FitCheckStep {
  auth,
  candidate,
  job,
  interviewer,
  difficulty,
  liveRoom,
  evaluation,
  history,
}

class FitCheckMainFlow extends StatefulWidget {
  final AuthService authService;
  final FitCheckApiService apiService;

  const FitCheckMainFlow({
    super.key,
    required this.authService,
    required this.apiService,
  });

  @override
  State<FitCheckMainFlow> createState() => _FitCheckMainFlowState();
}

class _FitCheckMainFlowState extends State<FitCheckMainFlow> {
  late FitCheckStep _currentStep;

  // Selected session setup entities
  FitCheckCandidate? _selectedCandidate;
  FitCheckJob? _selectedJob;
  FitCheckInterviewer? _selectedInterviewer;
  FitCheckSession? _activeSession;
  String? _evaluationSessionId;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.authService.currentUser == null ? FitCheckStep.auth : FitCheckStep.candidate;
  }

  void _resetFlow() {
    setState(() {
      _selectedCandidate = null;
      _selectedJob = null;
      _selectedInterviewer = null;
      _activeSession = null;
      _evaluationSessionId = null;
      _currentStep = FitCheckStep.candidate;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case FitCheckStep.auth:
        return FitCheckAuthPage(
          authService: widget.authService,
          onAuthenticated: () => setState(() => _currentStep = FitCheckStep.candidate),
        );

      case FitCheckStep.candidate:
        return Scaffold(
          body: CandidateProfilePage(
            apiService: widget.apiService,
            currentUser: widget.authService.currentUser,
            onSignOut: () async {
              await widget.authService.signOut();
              setState(() {
                _resetFlow();
                _currentStep = FitCheckStep.auth;
              });
            },
            onCandidateSelected: (cand) {
              setState(() {
                _selectedCandidate = cand;
                _currentStep = FitCheckStep.job;
              });
            },
          ),
          bottomNavigationBar: _buildBottomNav(0),
        );

      case FitCheckStep.job:
        return Scaffold(
          body: JobSelectionPage(
            apiService: widget.apiService,
            onJobSelected: (job) {
              setState(() {
                _selectedJob = job;
                _currentStep = FitCheckStep.interviewer;
              });
            },
          ),
          bottomNavigationBar: _buildBottomNav(0),
        );

      case FitCheckStep.interviewer:
        return Scaffold(
          body: InterviewerSelectionPage(
            apiService: widget.apiService,
            onInterviewerSelected: (interviewer) {
              setState(() {
                _selectedInterviewer = interviewer;
                _currentStep = FitCheckStep.difficulty;
              });
            },
          ),
          bottomNavigationBar: _buildBottomNav(0),
        );

      case FitCheckStep.difficulty:
        return Scaffold(
          body: DifficultyAndPreparationPage(
            candidate: _selectedCandidate!,
            job: _selectedJob!,
            interviewer: _selectedInterviewer!,
            apiService: widget.apiService,
            onSessionLaunched: (session) {
              setState(() {
                _activeSession = session;
                _currentStep = FitCheckStep.liveRoom;
              });
            },
          ),
          bottomNavigationBar: _buildBottomNav(0),
        );

      case FitCheckStep.liveRoom:
        return FitCheckLiveInterviewRoom(
          session: _activeSession!,
          interviewer: _selectedInterviewer!,
          candidate: _selectedCandidate,
          apiService: widget.apiService,
          onInterviewEnded: (endedSession) {
            setState(() {
              _evaluationSessionId = endedSession.id;
              _currentStep = FitCheckStep.evaluation;
            });
          },
        );

      case FitCheckStep.evaluation:
        return FitCheckEvaluationReportPage(
          sessionId: _evaluationSessionId!,
          apiService: widget.apiService,
          onDone: _resetFlow,
        );

      case FitCheckStep.history:
        return Scaffold(
          body: FitCheckHistoryPage(
            apiService: widget.apiService,
            onSelectSession: (sessId) {
              setState(() {
                _evaluationSessionId = sessId;
                _currentStep = FitCheckStep.evaluation;
              });
            },
          ),
          bottomNavigationBar: _buildBottomNav(1),
        );
    }
  }

  Widget _buildBottomNav(int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: FitCheckTheme.surface,
      selectedItemColor: FitCheckTheme.primary,
      unselectedItemColor: FitCheckTheme.textMuted,
      onTap: (index) {
        if (index == 0) {
          setState(() => _currentStep = FitCheckStep.candidate);
        } else if (index == 1) {
          setState(() => _currentStep = FitCheckStep.history);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.psychology_outlined),
          activeIcon: Icon(Icons.psychology),
          label: 'Simulate',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          activeIcon: Icon(Icons.history_rounded),
          label: 'History',
        ),
      ],
    );
  }
}

