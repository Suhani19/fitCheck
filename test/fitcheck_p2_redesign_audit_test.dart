import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/live_interview_room_page.dart';
import 'package:fitcheck/features/fitcheck/screens/app_settings_page.dart';
import 'package:fitcheck/features/fitcheck/screens/fitcheck_shell.dart';
import 'package:fitcheck/features/fitcheck/screens/learning_plan_page.dart';
import 'package:fitcheck/features/fitcheck/screens/notifications_page.dart';
import 'package:fitcheck/features/fitcheck/screens/public_landing_page.dart';
import 'package:fitcheck/features/fitcheck/screens/skill_analytics_page.dart';
import 'package:fitcheck/features/fitcheck/widgets/candidate_sidebar.dart';

class MockAuthService implements AuthService {
  FitCheckUser? _user;
  late final Stream<FitCheckUser?> _stream;

  MockAuthService({FitCheckUser? user}) : _user = user {
    _stream = Stream.value(user);
  }

  @override
  FitCheckUser? get currentUser => _user;

  @override
  Stream<FitCheckUser?> get authStateChanges => _stream;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _user != null ? 'mock-token' : null;

  @override
  bool get isConfigured => true;

  @override
  Future<FitCheckUser> signInWithEmailAndPassword(
      {required String email, required String password}) async {
    _user = FitCheckUser(uid: 'mock-uid-1', email: email, displayName: 'Test User');
    return _user!;
  }

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword(
      {required String email, required String password, String? displayName}) async {
    _user =
        FitCheckUser(uid: 'mock-uid-1', email: email, displayName: displayName ?? 'Test User');
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FitCheck P2 Phase 3: Five-Group Candidate Sidebar', () {
    testWidgets('Sidebar displays exactly the five required group headings', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: CandidateSidebar(
              currentRoute: FitCheckRoute.commandCenter,
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 5 exact group headings
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('PREPARE'), findsOneWidget);
      expect(find.text('INTERVIEWS'), findsOneWidget);
      expect(find.text('PROGRESS'), findsOneWidget);
      expect(find.text('PERSONAL & SUPPORT'), findsOneWidget);

      // Verify page titles under these groups
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Target Jobs & Rubrics'), findsOneWidget);
      expect(find.text('Interviewer Library'), findsOneWidget);
      expect(find.text('Practice Library'), findsOneWidget);
      expect(find.text('Learning Plan'), findsOneWidget);
      expect(find.text('Interview History'), findsOneWidget);
      expect(find.text('Skill Analytics'), findsOneWidget);
      expect(find.text('Candidate Profile'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Help & FAQ'), findsOneWidget);

      // Landing page must NOT be a destination for authenticated candidates
      expect(find.text('Landing Page'), findsNothing);
    });

    testWidgets('Sidebar navigation fires onNavigate with correct route', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FitCheckRoute? navigatedRoute;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: CandidateSidebar(
              currentRoute: FitCheckRoute.commandCenter,
              onNavigate: (route) => navigatedRoute = route,
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Skill Analytics'
      await tester.tap(find.text('Skill Analytics'));
      expect(navigatedRoute, FitCheckRoute.skillAnalytics);

      // Tap 'Learning Plan'
      await tester.tap(find.text('Learning Plan'));
      expect(navigatedRoute, FitCheckRoute.learningPlan);
    });

    testWidgets('Sidebar sign-out callback triggers cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: CandidateSidebar(
              currentRoute: FitCheckRoute.commandCenter,
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () => signedOut = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sidebar_sign_out_button')));
      expect(signedOut, isTrue);
    });
  });

  group('FitCheck P2 Phase 4: Public Landing Page & Honest Pricing', () {
    testWidgets('Landing page renders header, nav items, and honest pricing tiers', (tester) async {
      tester.view.physicalSize = const Size(1280, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool signInTapped = false;
      bool getStartedTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: PublicLandingPage(
              onSignIn: () => signInTapped = true,
              onStartPreparing: () => getStartedTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand
      expect(find.text('FitCheck'), findsAtLeastNWidgets(1));

      // Header Navigation Items
      expect(find.text('Platform'), findsOneWidget);
      expect(find.text('Interviewer Personas'), findsOneWidget);
      expect(find.text('Voice Studio'), findsOneWidget);
      expect(find.text('Evaluations'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);

      // Auth actions
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));
      expect(find.text('Start Preparing Free'), findsAtLeastNWidgets(1));

      // Verify Honest Pricing Content
      expect(find.text('HONEST ACCESS & PLANS'), findsOneWidget);
      expect(find.text('Choose How You Prepare'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pay as you go'), findsOneWidget);
      expect(find.text('STANDARD ACCESS'), findsOneWidget);
      expect(find.text('EXPANDED CAPABILITIES'), findsOneWidget);

      // Check planned feature labels
      expect(find.textContaining('Video interview calls [Planned / Roadmap]'), findsOneWidget);
      expect(find.textContaining('Multiple concurrent interviewer voices'), findsOneWidget);

      // Verify sign in trigger
      await tester.tap(find.text('Sign In').first);
      expect(signInTapped, isTrue);

      // Verify start preparing trigger
      await tester.tap(find.text('Start Preparing Free').first);
      expect(getStartedTapped, isTrue);
    });
  });

  group('FitCheck P2 Phase 2: Real-Data & Honest Empty States Audit', () {
    testWidgets('AppSettingsPage loads and persists settings via SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: AppSettingsPage(
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hardware & Simulation Calibration'), findsOneWidget);
      expect(find.textContaining('Acoustic Echo Cancellation'), findsOneWidget);

      // Find a switch and toggle it
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsWidgets);

      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_echo_cancellation'), isNotNull);
    });

    testWidgets('NotificationsPage shows honest empty state when candidate has no sessions', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: NotificationsPage(
              sessions: const [],
              evaluations: const [],
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(find.textContaining('When you complete a live simulation session'), findsOneWidget);
    });

    testWidgets('NotificationsPage dynamically renders evaluation notifications when present', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const sampleEval = FitCheckEvaluation(
        id: 'eval-1',
        sessionId: 'session-1',
        overallScore: 84.0,
        overallRecommendation: 'Strong Pass',
        summaryVerdict: 'Solid trade-off articulation',
        competencyScores: [
          {'name': 'Distributed Systems', 'score': 85}
        ],
        observedStrengths: ['Clear consensus reasoning'],
        technicalGaps: ['Cache invalidation race conditions'],
        preparationRecommendations: ['Review Raft lease timers'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: NotificationsPage(
              sessions: const [],
              evaluations: const [sampleEval],
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Evaluation Ready: Strong Pass'), findsOneWidget);
      expect(find.textContaining('Score: 84%'), findsOneWidget);
      expect(find.textContaining('Solid trade-off articulation'), findsOneWidget);
    });

    testWidgets('SkillAnalyticsPage shows honest zero-data state when no evaluations exist', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: SkillAnalyticsPage(
              evaluations: const [],
              sessions: const [],
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Skill Analytics & Telemetry'), findsOneWidget);
      expect(find.text('No Skill Analytics Recorded Yet'), findsOneWidget);
      expect(find.textContaining('Complete your first interview simulation'), findsOneWidget);
    });

    testWidgets('LearningPlanPage shows honest empty state with sample curriculum toggle', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: LearningPlanPage(
              evaluations: const [],
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personalized Learning Roadmap'), findsOneWidget);
      expect(find.text('No Learning Plan Generated Yet'), findsOneWidget);
      expect(find.text('Preview Sample Syllabus'), findsOneWidget);

      // Tap preview
      await tester.tap(find.text('Preview Sample Syllabus'));
      await tester.pumpAndSettle();

      expect(find.text('SAMPLE PREVIEW ONLY'), findsOneWidget);
    });
  });

  group('FitCheck P2 Phase 1: Live Voice Interview Room Redesign', () {
    testWidgets('FitCheckLiveInterviewRoom displays approved Stitch layout elements', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = FitCheckSession(
        id: 'sess-unit-p2',
        candidateId: 'demo-elena-cand',
        jobId: 'job-dist-sys',
        interviewerId: 'int-marcus',
        difficulty: 'realistic',
        status: 'active',
        channel: 'fitcheck-demo-channel',
        startedAt: DateTime.now().toIso8601String(),
        sessionPlan: const {'scenario': 'Distributed Storage System Design'},
        transcript: const [
          {'role': 'interviewer', 'text': 'How do you handle split-brain in Raft?'}
        ],
      );

      final apiService = FitCheckApiService(
        client: AuthenticatedApiClient(authService: MockAuthService()),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: const FitCheckInterviewer(
              id: 'int-marcus',
              name: 'Marcus Vance',
              title: 'Staff Systems Architect',
              companyContext: 'Stripe',
              questioningStyle: 'deep_probing',
              voiceId: 'Puck',
            ),
            candidate: const FitCheckCandidate(
              id: 'demo-elena-cand',
              fullName: 'Elena Rostova',
            ),
            apiService: apiService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Top Sub-Bar
      expect(find.text('STAGE: INTRODUCTION'), findsOneWidget);
      expect(find.text('Scenario: '), findsOneWidget);
      expect(find.text('Distributed Storage System Design'), findsOneWidget);

      // Acoustic stream header
      expect(find.text('ACOUSTIC TRANSCRIPTION STREAM'), findsOneWidget);
      expect(find.text('Whisper v3 / WebRTC Native Real-time'), findsOneWidget);

      // Interviewer presence
      expect(find.text('Marcus Vance'), findsAtLeastNWidgets(1));
      expect(find.text('Interviewer Observation Log'), findsOneWidget);

      // Controls Bar
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Speaker On'), findsOneWidget);
      expect(find.text('Audio Devices'), findsOneWidget);
      expect(find.text('End Interview'), findsOneWidget);
    });
  });
}
