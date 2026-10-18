import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/app.dart';
import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/config/app_config.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/call/call_session_manager.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/live_interview_room_page.dart';
import 'package:fitcheck/features/fitcheck/screens/fitcheck_shell.dart';

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
  Future<String?> getIdToken({bool forceRefresh = false}) async => _user != null ? 'mock-token' : null;

  @override
  bool get isConfigured => true;

  @override
  Future<FitCheckUser> signInWithEmailAndPassword({required String email, required String password}) async {
    _user = FitCheckUser(uid: 'mock-uid-1', email: email, displayName: 'Test User');
    return _user!;
  }

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({required String email, required String password, String? displayName}) async {
    _user = FitCheckUser(uid: 'mock-uid-1', email: email, displayName: displayName ?? 'Test User');
    return _user!;
  }

  @override
  Future<FitCheckUser> signInAsDemo() async {
    _user = const FitCheckUser(uid: 'demo-candidate-elena', email: 'elena.demo@fitcheck.io', displayName: 'Elena Rostova');
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  group('FitCheck P0 Diagnostic & Root-Cause Fix Verification', () {
    tearDown(() {
      CallSessionManager.instance.endCall();
    });

    testWidgets('1. Startup: FitCheckApp directly mounts FitCheckShell without legacy onboarding intercept', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Even if initialOnboardingCompleted was explicitly false, FitCheckApp launches FitCheckShell
      await tester.pumpWidget(
        const FitCheckApp(initialOnboardingCompleted: false),
      );
      await tester.pump();

      expect(find.byType(FitCheckShell), findsOneWidget);
      expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
      expect(find.text('Create someone.'), findsNothing);
      expect(find.text('Your Characters'), findsNothing);
    });

    testWidgets('2. Demo Mode Boundary: Explores demo candidate without fake auth failures', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: FitCheckShell(
            authService: MockAuthService(user: null),
            initialRoute: FitCheckRoute.auth,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('demo_candidate_sign_in_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('demo_candidate_sign_in_button')));
      await tester.pump();

      // Enters Command Center with DEMO MODE banner and badge
      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
      expect(find.text('DEMO MODE • SAMPLE DATA'), findsOneWidget);
      expect(find.textContaining('DEMO MODE (Simulated Candidate'), findsOneWidget);

      // In Demo Mode, Edit Profile updates in-memory and shows explanatory feedback
      expect(find.byKey(const Key('edit_candidate_profile_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit_candidate_profile_button')));
      await tester.pump();

      expect(find.text('Edit Candidate Profile'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('candidate_edit_headline_field')), 'Demo Updated Headline');
      await tester.tap(find.byKey(const Key('candidate_save_profile_button')));
      await tester.pump();

      expect(find.textContaining('Demo profile updated in memory'), findsOneWidget);
    });

    testWidgets('3. Hardware Setup to Live Room: Navigates to FitCheckLiveInterviewRoom', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: FitCheckShell(
            authService: MockAuthService(user: null),
            initialRoute: FitCheckRoute.auth,
          ),
        ),
      );
      await tester.pump();

      // Enter as candidate
      await tester.tap(find.byKey(const Key('demo_candidate_sign_in_button')));
      await tester.pump();

      // Navigate to hardware setup
      await tester.tap(find.text('Start Live Interview'));
      await tester.pump();

      expect(find.text('Difficulty & Stress Calibration'), findsOneWidget);
      expect(find.text('Enter Live Interview Room'), findsOneWidget);

      await tester.tap(find.text('Enter Live Interview Room'));
      await tester.pump();

      // Verifies FitCheckLiveInterviewRoom is the active live experience
      expect(find.byType(FitCheckLiveInterviewRoom), findsOneWidget);
      expect(find.text('End Interview'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsWidgets);
    });

    testWidgets('4. Live Room Completion & Scorecard Evaluation Callback', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = FitCheckSession(
        id: 'sess-unit-1',
        candidateId: 'demo-elena-cand',
        jobId: 'job-dist-sys',
        interviewerId: 'int-marcus',
        difficulty: 'realistic',
        status: 'active',
        channel: 'fitcheck-demo-channel',
        startedAt: DateTime.now().toIso8601String(),
        transcript: const [
          {'role': 'interviewer', 'text': 'How do you handle split-brain in Raft?'}
        ],
      );

      bool interviewEnded = false;
      FitCheckSession? finalizedSession;

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
            apiService: FitCheckApiService(
              client: AuthenticatedApiClient(authService: MockAuthService()),
            ),
            onInterviewEnded: (ended) {
              interviewEnded = true;
              finalizedSession = ended;
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('End Interview'), findsOneWidget);
      await tester.tap(find.text('End Interview'));
      await tester.pump();

      expect(find.text('End Interview Session?'), findsOneWidget);
      expect(find.text('End & Evaluate'), findsOneWidget);

      await tester.tap(find.text('End & Evaluate'));
      await tester.pump();

      expect(interviewEnded, isTrue);
      expect(finalizedSession?.status, equals('ended'));
    });

    test('5. Backend URL Dynamic Resolution', () {
      final url = AppConfig.backendUrl;
      expect(url.isNotEmpty, isTrue);
      expect(url.startsWith('http'), isTrue);
    });
  });
}
