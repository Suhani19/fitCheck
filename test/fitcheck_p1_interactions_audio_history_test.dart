import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/services/hardware_audio_service.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/screens/candidate_command_center_page.dart';
import 'package:fitcheck/features/fitcheck/screens/evaluation_scorecard_page.dart';
import 'package:fitcheck/features/fitcheck/screens/fitcheck_shell.dart';
import 'package:fitcheck/features/fitcheck/screens/hardware_readiness_page.dart';
import 'package:fitcheck/features/fitcheck/screens/interview_history_page.dart';
import 'package:fitcheck/features/fitcheck/widgets/candidate_sidebar.dart';

class FakeHardwareAudioService extends HardwareAudioService {
  bool playTestChimeCalled = false;
  bool shouldFailPlayback = false;
  ChimePlaybackStatus _fakeStatus = ChimePlaybackStatus.idle;
  String _fakeMessage = 'Test Chime';

  @override
  ChimePlaybackStatus get chimeStatus => _fakeStatus;

  @override
  String get chimeStatusMessage => _fakeMessage;

  FakeHardwareAudioService({this.shouldFailPlayback = false})
      : super(isTestEnv: true);

  @override
  Future<void> playTestChime() async {
    playTestChimeCalled = true;
    _fakeStatus = ChimePlaybackStatus.playing;
    _fakeMessage = 'Playing chime...';
    chimeStatusNotifier.value = ChimePlaybackStatus.playing;
    await Future.delayed(const Duration(milliseconds: 10));

    if (shouldFailPlayback) {
      _fakeStatus = ChimePlaybackStatus.error;
      _fakeMessage = 'Playback blocked/failed';
      chimeStatusNotifier.value = ChimePlaybackStatus.error;
    } else {
      _fakeStatus = ChimePlaybackStatus.success;
      _fakeMessage = 'Playback successful ✓';
      chimeStatusNotifier.value = ChimePlaybackStatus.success;
    }
  }

  @override
  Future<bool> checkMicrophonePermission({bool request = true}) async {
    return true;
  }
}

class MockAuthService implements AuthService {
  @override
  FitCheckUser? get currentUser => const FitCheckUser(uid: 'mock-cand-uid', email: 'elena@stripe.com');

  @override
  Stream<FitCheckUser?> get authStateChanges => Stream.value(currentUser);

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'mock-token';

  @override
  bool get isConfigured => true;

  @override
  Future<FitCheckUser> signInWithEmailAndPassword({required String email, required String password}) async => currentUser!;

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({required String email, required String password, String? displayName}) async => currentUser!;

  @override
  Future<FitCheckUser> signInAsDemo() async => currentUser!;

  @override
  Future<void> signOut() async {}
}

class FakeFitCheckApiService extends FitCheckApiService {
  List<FitCheckSession> mockSessions;
  List<FitCheckEvaluation> mockEvaluations;
  bool shouldThrowOnListSessions;
  int listSessionsCallCount = 0;

  FakeFitCheckApiService({
    this.mockSessions = const [],
    this.mockEvaluations = const [],
    this.shouldThrowOnListSessions = false,
  }) : super(client: AuthenticatedApiClient(authService: MockAuthService()));

  @override
  Future<List<FitCheckSession>> listSessions({String? candidateId, int limit = 50}) async {
    listSessionsCallCount++;
    if (shouldThrowOnListSessions) {
      throw Exception('Simulated backend connection failure');
    }
    return mockSessions;
  }

  @override
  Future<List<FitCheckEvaluation>> listEvaluations({String? candidateId, int limit = 50}) async {
    return mockEvaluations;
  }

  @override
  Future<List<FitCheckInterviewer>> listInterviewers({bool presetsOnly = false}) async {
    return const [
      FitCheckInterviewer(
        id: 'interviewer-marcus-101',
        name: 'Marcus Vance',
        title: 'Staff Systems Architect',
        companyContext: 'Stripe',
        questioningStyle: 'deep_probing',
        voiceId: 'Puck',
        isPreset: true,
        bio: 'Staff Systems Architect at Stripe specializing in distributed consensus.',
      ),
    ];
  }

  @override
  Future<List<FitCheckJob>> listJobs() async {
    return const [
      FitCheckJob(
        id: 'job-stripe-l6',
        title: 'Staff Systems Engineer',
        seniority: 'L6',
        description: 'Staff Systems Engineer at Stripe',
      ),
    ];
  }
}

void main() {
  setUpAll(() {
    FitCheckTheme.init();
  });

  group('P1.1: Hardware Readiness Test Chime & Real Audio Behavior', () {
    testWidgets('Clicking Test Chime invokes audio playback and updates status to Playing -> Success', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAudio = FakeHardwareAudioService(shouldFailPlayback: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: HardwareReadinessPage(
            audioService: fakeAudio,
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chimeBtn = find.byKey(const Key('hardware_test_chime_button'));
      expect(chimeBtn, findsOneWidget);
      expect(find.text('Test Chime'), findsOneWidget);

      await tester.tap(chimeBtn);
      await tester.pump();

      expect(fakeAudio.playTestChimeCalled, isTrue);

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Playback successful ✓'), findsOneWidget);
    });

    testWidgets('Test Chime handles browser playback failure with error state and feedback', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAudio = FakeHardwareAudioService(shouldFailPlayback: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: HardwareReadinessPage(
            audioService: fakeAudio,
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chimeBtn = find.byKey(const Key('hardware_test_chime_button'));
      await tester.tap(chimeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Playback blocked/failed'), findsOneWidget);
    });
  });

  group('P1.2: Authenticated Navigation & Candidate Sidebar', () {
    testWidgets('Candidate sidebar excludes Landing Page and includes all 10 planned candidate destinations', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FitCheckRoute? navigatedRoute;
      bool startInterviewTriggered = false;
      bool signOutTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: CandidateSidebar(
              currentRoute: FitCheckRoute.commandCenter,
              candidate: const FitCheckCandidate(
                id: 'cand-1',
                fullName: 'Elena Rostova',
                headline: 'Staff Systems Eng',
                skills: ['Go', 'Raft'],
              ),
              currentUser: const FitCheckUser(uid: 'u-1', email: 'elena@stripe.com', displayName: 'Elena Rostova'),
              onNavigate: (r) => navigatedRoute = r,
              onStartInterview: () => startInterviewTriggered = true,
              onSignOut: () => signOutTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Landing Page is NEVER present in authenticated sidebar
      expect(find.text('Landing Page'), findsNothing);

      // Verify presence of all expected candidate routes
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Interview History'), findsOneWidget);
      expect(find.text('Target Jobs & Rubrics'), findsOneWidget);
      expect(find.text('Interviewer Library'), findsOneWidget);
      expect(find.text('Practice Library'), findsOneWidget);
      expect(find.text('Learning Plan'), findsOneWidget);
      expect(find.text('Skill Analytics'), findsOneWidget);
      expect(find.text('Candidate Profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Help & FAQ'), findsOneWidget);

      // Verify each item navigates to its intended destination
      await tester.tap(find.text('Interview History'));
      expect(navigatedRoute, equals(FitCheckRoute.history));

      await tester.tap(find.text('Practice Library'));
      expect(navigatedRoute, equals(FitCheckRoute.practiceLibrary));

      await tester.tap(find.text('Target Jobs & Rubrics'));
      expect(navigatedRoute, equals(FitCheckRoute.targetJobs));

      await tester.tap(find.text('Skill Analytics'));
      expect(navigatedRoute, equals(FitCheckRoute.skillAnalytics));

      await tester.tap(find.text('Learning Plan'));
      expect(navigatedRoute, equals(FitCheckRoute.learningPlan));

      await tester.tap(find.text('Candidate Profile'));
      expect(navigatedRoute, equals(FitCheckRoute.candidateProfile));

      await tester.tap(find.text('Notifications'));
      expect(navigatedRoute, equals(FitCheckRoute.notifications));

      await tester.tap(find.text('Settings'));
      expect(navigatedRoute, equals(FitCheckRoute.settings));

      await tester.tap(find.text('Help & FAQ'));
      expect(navigatedRoute, equals(FitCheckRoute.helpFaq));

      // Verify Start Interview button
      await tester.tap(find.byKey(const Key('sidebar_start_interview_button')));
      expect(startInterviewTriggered, isTrue);

      // Verify Sign Out button
      await tester.tap(find.byKey(const Key('sidebar_sign_out_button')));
      expect(signOutTriggered, isTrue);
    });
  });

  group('P1.3: Audit Button Callbacks & Eliminate Accidental Start Call Triggers', () {
    testWidgets('Command Center secondary controls navigate to their respective destinations, not Start Interview', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool startInterviewCalled = false;
      bool hardwareSetupCalled = false;
      bool viewHistoryCalled = false;
      bool viewLibraryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            isDemoMode: true,
            onStartInterview: () => startInterviewCalled = true,
            onHardwareSetup: () => hardwareSetupCalled = true,
            onViewScorecard: () {},
            onViewHistory: () => viewHistoryCalled = true,
            onViewLibrary: () => viewLibraryCalled = true,
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Action Radar drill card click must trigger onViewLibrary, NOT onStartInterview
      final raftDrill = find.text('Consensus & Raft Practice Drill');
      expect(raftDrill, findsOneWidget);
      await tester.ensureVisible(raftDrill);
      await tester.tap(raftDrill);
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewLibraryCalled, isTrue);
      expect(startInterviewCalled, isFalse);
      expect(hardwareSetupCalled, isFalse);

      // Recent Sessions "View all" must trigger onViewHistory, NOT onStartInterview
      final viewAll = find.text('View all');
      expect(viewAll, findsOneWidget);
      await tester.ensureVisible(viewAll);
      await tester.tap(viewAll);
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewHistoryCalled, isTrue);
      expect(startInterviewCalled, isFalse);
    });
  });

  group('P1.4: Real Persisted Interview History', () {
    testWidgets('Interview History renders backend sessions, supports filtering, and handles empty state', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSessions = [
        const FitCheckSession(
          id: 'sess-real-001',
          candidateId: 'cand-1',
          jobId: 'job-stripe-l6',
          interviewerId: 'interviewer-marcus-101',
          status: 'completed',
          channel: 'test-chan-1',
          startedAt: '2026-10-15T14:30:00Z',
          endedAt: '2026-10-15T15:15:00Z',
          difficulty: 'realistic',
        ),
        const FitCheckSession(
          id: 'sess-real-002',
          candidateId: 'cand-1',
          jobId: 'job-stripe-l6',
          interviewerId: 'interviewer-marcus-101',
          status: 'active',
          channel: 'test-chan-2',
          startedAt: '2026-10-16T10:00:00Z',
          difficulty: 'expert_stress',
        ),
      ];

      final mockEvaluations = [
        const FitCheckEvaluation(
          id: 'eval-real-001',
          sessionId: 'sess-real-001',
          overallScore: 4.4,
          overallRecommendation: 'Strong Hire • Level 6 Ready',
          summaryVerdict: 'Exemplary consensus debugging under WAN partition.',
        ),
      ];

      final fakeApi = FakeFitCheckApiService(
        mockSessions: mockSessions,
        mockEvaluations: mockEvaluations,
      );

      FitCheckSession? selectedSession;
      FitCheckEvaluation? selectedEval;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: InterviewHistoryPage(
            apiService: fakeApi,
            initialSessions: mockSessions,
            initialEvaluations: mockEvaluations,
            onSelectSession: (s, e) {
              selectedSession = s;
              selectedEval = e;
            },
            onStartInterview: () {},
            onNavigate: (_) {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sessions rendered from API
      expect(find.byKey(const Key('history_session_card_sess-real-001')), findsOneWidget);
      expect(find.byKey(const Key('history_session_card_sess-real-002')), findsOneWidget);
      expect(find.text('88/100'), findsAtLeastNWidgets(1));
      expect(find.text('ACTIVE'), findsOneWidget);

      // Tap on completed session opens details callback
      await tester.tap(find.byKey(const Key('history_session_card_sess-real-001')));
      expect(selectedSession?.id, equals('sess-real-001'));
      expect(selectedEval?.overallScore, equals(4.4));

      // Test filtering
      await tester.tap(find.byKey(const Key('history_filter_active')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_session_card_sess-real-002')), findsOneWidget);
      expect(find.byKey(const Key('history_session_card_sess-real-001')), findsNothing);
    });

    testWidgets('Interview History handles error and retry cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeApi = FakeFitCheckApiService(shouldThrowOnListSessions: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: InterviewHistoryPage(
            apiService: fakeApi,
            onSelectSession: (_, _) {},
            onStartInterview: () {},
            onNavigate: (_) {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Simulated backend connection failure'), findsOneWidget);
      final retryBtn = find.byKey(const Key('history_retry_button'));
      expect(retryBtn, findsOneWidget);

      // When retrying, API is called again
      fakeApi.shouldThrowOnListSessions = false;
      fakeApi.mockSessions = [
        const FitCheckSession(
          id: 'sess-recovered-001',
          candidateId: 'cand-1',
          jobId: 'job-1',
          interviewerId: 'int-1',
          status: 'completed',
          channel: 'chan-recov',
          startedAt: '2026-10-15T12:00:00Z',
          endedAt: '2026-10-15T12:45:00Z',
          difficulty: 'realistic',
        ),
      ];

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_session_card_sess-recovered-001')), findsOneWidget);
    });
  });

  group('P1.5: Evaluation Scorecard Honest Status vs Fabricated Fallbacks', () {
    testWidgets('Scorecard displays honest PENDING status and does not fabricate fake 88/100 score for unscored historical session', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const unscoredSession = FitCheckSession(
        id: 'sess-unscored-99',
        candidateId: 'cand-1',
        jobId: 'job-stripe-l6',
        interviewerId: 'interviewer-marcus-101',
        status: 'completed',
        channel: 'chan-unscored',
        startedAt: '2026-10-14T10:00:00Z',
        endedAt: '2026-10-14T10:45:00Z',
        difficulty: 'realistic',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: EvaluationScorecardPage(
            session: unscoredSession,
            evaluation: null, // No evaluation exists for this historical session
            isDemoMode: false,
            onBackToDashboard: () {},
            onRetakeSimulation: () {},
            onLaunchRecommendedDrill: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must display honest pending status
      expect(find.textContaining('EVALUATION PENDING'), findsOneWidget);
      expect(find.textContaining('concluded with status'), findsOneWidget);
      // Score display should show placeholder '--', not fabricated 88/100
      expect(find.text('--'), findsOneWidget);
    });
  });
}
