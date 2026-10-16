import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/services/hardware_audio_service.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/screens/hardware_readiness_page.dart';
import 'package:fitcheck/features/fitcheck/screens/interviewer_library_page.dart';
import 'package:fitcheck/features/fitcheck/services/interviewer_recommendation_service.dart';

class MockTestAuthService implements AuthService {
  @override
  FitCheckUser? get currentUser => const FitCheckUser(uid: 'test-cand-uid', email: 'alex@fitcheck.io', displayName: 'Alex Cand');

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
  Future<void> signOut() async {}
}

class FakeTestHardwareAudioService extends HardwareAudioService {
  FakeTestHardwareAudioService() : super(isTestEnv: true);

  @override
  Future<bool> checkMicrophonePermission({bool request = true}) async => true;

  @override
  Future<void> playTestChime() async {}
}

class FakeInterviewerApiService extends FitCheckApiService {
  final List<FitCheckInterviewer> interviewers;
  final List<FitCheckJob> jobs;
  FitCheckSession? lastCreatedSession;
  String? lastStartedCandidateId;
  String? lastStartedInterviewerId;
  String? lastStartedJobId;
  String? lastStartedDifficulty;
  bool shouldFailGetInterviewers;

  FakeInterviewerApiService({
    required this.interviewers,
    required this.jobs,
    this.shouldFailGetInterviewers = false,
  }) : super(client: AuthenticatedApiClient(authService: MockTestAuthService()));

  @override
  Future<FitCheckCandidate?> getCurrentCandidate() async {
    return const FitCheckCandidate(
      id: 'cand-test-1',
      fullName: 'Elena Rostova',
      headline: 'Staff Systems Engineer',
      skills: ['Go', 'Raft', 'Distributed Systems'],
    );
  }

  @override
  Future<List<FitCheckInterviewer>> listInterviewers({bool presetsOnly = false}) async {
    if (shouldFailGetInterviewers) {
      throw Exception('Network unreachable for interviewer catalogue');
    }
    return interviewers;
  }

  @override
  Future<List<FitCheckJob>> listJobs() async {
    return jobs;
  }

  @override
  Future<List<FitCheckSession>> listSessions({String? candidateId, int limit = 50}) async {
    return lastCreatedSession != null ? [lastCreatedSession!] : [];
  }

  @override
  Future<List<FitCheckEvaluation>> listEvaluations({String? candidateId, int limit = 50}) async {
    return [];
  }

  @override
  Future<FitCheckSession> startSession({
    required String candidateId,
    required String jobId,
    required String interviewerId,
    String difficulty = 'realistic',
  }) async {
    lastStartedCandidateId = candidateId;
    lastStartedJobId = jobId;
    lastStartedInterviewerId = interviewerId;
    lastStartedDifficulty = difficulty;

    final session = FitCheckSession(
      id: 'sess-${DateTime.now().millisecondsSinceEpoch}',
      candidateId: candidateId,
      jobId: jobId,
      interviewerId: interviewerId,
      difficulty: difficulty,
      status: 'active',
      channel: 'fitcheck-test-channel',
      startedAt: DateTime.now().toIso8601String(),
    );
    lastCreatedSession = session;
    return session;
  }
}

final testAlexInterviewer = const FitCheckInterviewer(
  id: 'alex-lead-001',
  name: 'Alex Rivera',
  title: 'Staff Full-Stack Product Engineer',
  companyContext: 'Vercel / Next.js',
  questioningStyle: 'conversational',
  voiceId: 'Puck',
  isPreset: true,
  bio: 'Staff Full-Stack Product Engineer focusing on modern web architecture and user experience.',
);

final testSarahInterviewer = const FitCheckInterviewer(
  id: 'sarah-em-001',
  name: 'Sarah Chen',
  title: 'Senior Engineering Manager',
  companyContext: 'Uber Core Infra',
  questioningStyle: 'rigorous',
  voiceId: 'Aoede',
  isPreset: true,
  bio: 'Senior Engineering Manager leading infrastructure reliability and incident response.',
);

final testMarcusInterviewer = const FitCheckInterviewer(
  id: 'marcus-arch-001',
  name: 'Marcus Vance',
  title: 'Principal Distributed Systems Architect',
  companyContext: 'Stripe',
  questioningStyle: 'challenging',
  voiceId: 'Fenrir',
  isPreset: true,
  bio: 'Principal Systems Architect specializing in distributed consensus and fault-tolerant storage.',
);

final testDistJob = const FitCheckJob(
  id: 'job-dist-sys',
  title: 'Staff Distributed Systems Engineer',
  seniority: 'L6 / Staff',
  requiredSkills: ['Raft', 'Distributed Storage', 'Consensus', 'Go'],
  description: 'Design highly available distributed data tier.',
);

final testFrontendJob = const FitCheckJob(
  id: 'job-fullstack',
  title: 'Staff Full-Stack Product Engineer',
  seniority: 'Staff',
  requiredSkills: ['React', 'Next.js', 'TypeScript', 'GraphQL', 'API Design'],
  description: 'Drive high-velocity frontend architecture and reactive UI.',
);

final testManagerJob = const FitCheckJob(
  id: 'job-eng-manager',
  title: 'Engineering Manager - Platform Reliability',
  seniority: 'Manager / Director',
  requiredSkills: ['Incident Management', 'Reliability', 'Mentorship', 'Roadmap'],
  description: 'Manage cross-functional platform engineering teams.',
);

void main() {
  setUpAll(() {
    FitCheckTheme.init();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('Interviewer Selection & Persistence Across Interview Flow', () {
    testWidgets('Scenario 1: Selecting Alex Rivera updates Hardware Readiness dossier and preserves Alex identity', (tester) async {
      configureViewport(tester);

      FitCheckInterviewer? selectedInterviewer;
      final apiService = FakeInterviewerApiService(
        interviewers: [testMarcusInterviewer, testSarahInterviewer, testAlexInterviewer],
        jobs: [testDistJob],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: InterviewerLibraryPage(
            apiService: apiService,
            candidate: const FitCheckCandidate(id: 'c1', fullName: 'Candidate', headline: 'Eng', skills: []),
            onNavigate: (_) {},
            onStartInterview: () {},
            onSignOut: () {},
            initialInterviewers: [testMarcusInterviewer, testSarahInterviewer, testAlexInterviewer],
            onSelectInterviewer: (interviewer) {
              selectedInterviewer = interviewer;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and select Alex Rivera card
      final alexSelectBtn = find.byKey(const Key('select_interviewer_alex-lead-001'));
      expect(alexSelectBtn, findsOneWidget);
      await tester.ensureVisible(alexSelectBtn);
      await tester.tap(alexSelectBtn);
      await tester.pumpAndSettle();

      expect(selectedInterviewer, isNotNull);
      expect(selectedInterviewer!.id, 'alex-lead-001');
      expect(selectedInterviewer!.name, 'Alex Rivera');

      // Now pump HardwareReadiness with Alex Rivera as the selected interviewer
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            interviewer: selectedInterviewer,
            job: testDistJob,
            apiService: apiService,
            audioService: FakeTestHardwareAudioService(),
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Alex Rivera is displayed in the Hardware Readiness dossier, NOT Marcus Vance
      final nameFinder = find.byKey(const Key('hardware_interviewer_name'));
      expect(nameFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(nameFinder);
      expect(textWidget.data, 'Alex Rivera');

      // Verify voice configuration badge shows Puck
      final voiceBadge = find.byKey(const Key('hardware_interviewer_voice_badge'));
      expect(voiceBadge, findsOneWidget);
      final voiceText = tester.widget<Text>(voiceBadge);
      expect(voiceText.data, contains('Puck'));
    });

    testWidgets('Scenario 2: Selecting Sarah Chen updates Hardware Readiness dossier with Sarah identity and Aoede voice', (tester) async {
      configureViewport(tester);

      final apiService = FakeInterviewerApiService(
        interviewers: [testMarcusInterviewer, testSarahInterviewer, testAlexInterviewer],
        jobs: [testManagerJob],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            interviewer: testSarahInterviewer,
            job: testManagerJob,
            apiService: apiService,
            audioService: FakeTestHardwareAudioService(),
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameFinder = find.byKey(const Key('hardware_interviewer_name'));
      expect(nameFinder, findsOneWidget);
      expect(tester.widget<Text>(nameFinder).data, 'Sarah Chen');

      final titleFinder = find.byKey(const Key('hardware_interviewer_title'));
      expect(titleFinder, findsOneWidget);
      expect(tester.widget<Text>(titleFinder).data, 'Senior Engineering Manager');

      final voiceBadge = find.byKey(const Key('hardware_interviewer_voice_badge'));
      expect(voiceBadge, findsOneWidget);
      expect(tester.widget<Text>(voiceBadge).data, contains('Aoede'));
    });

    testWidgets('Scenario 3: Marcus Vance selection displays Marcus and Fenrir voice', (tester) async {
      configureViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            interviewer: testMarcusInterviewer,
            job: testDistJob,
            audioService: FakeTestHardwareAudioService(),
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nameFinder = find.byKey(const Key('hardware_interviewer_name'));
      expect(nameFinder, findsOneWidget);
      expect(tester.widget<Text>(nameFinder).data, 'Marcus Vance');

      final voiceBadge = find.byKey(const Key('hardware_interviewer_voice_badge'));
      expect(voiceBadge, findsOneWidget);
      expect(tester.widget<Text>(voiceBadge).data, contains('Fenrir'));
    });

    testWidgets('Scenario 4 & 5: Starting session persists selected interviewer ID', (tester) async {
      configureViewport(tester);

      final apiService = FakeInterviewerApiService(
        interviewers: [testMarcusInterviewer, testSarahInterviewer, testAlexInterviewer],
        jobs: [testDistJob],
      );

      FitCheckSession? createdSession;
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            candidate: const FitCheckCandidate(id: 'cand-real-1', fullName: 'Candidate', headline: 'Eng', skills: []),
            interviewer: testAlexInterviewer,
            job: testDistJob,
            apiService: apiService,
            audioService: FakeTestHardwareAudioService(),
            onSessionCreated: (s) => createdSession = s,
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final enterBtn = find.byKey(const Key('enter_live_room_button'));
      expect(enterBtn, findsOneWidget);
      await tester.ensureVisible(enterBtn);
      await tester.tap(enterBtn);
      await tester.pumpAndSettle();

      expect(apiService.lastStartedInterviewerId, 'alex-lead-001');
      expect(createdSession, isNotNull);
      expect(createdSession!.interviewerId, 'alex-lead-001');
    });

    testWidgets('Scenario 6 & 7: Persona details expose distinct supported voice configurations and directives', (tester) async {
      // Alex Rivera: Puck
      expect(testAlexInterviewer.voiceDisplayName, contains('Puck'));
      expect(testAlexInterviewer.behavioralDirective, contains('Alex'));

      // Sarah Chen: Aoede
      expect(testSarahInterviewer.voiceDisplayName, contains('Aoede'));
      expect(testSarahInterviewer.behavioralDirective, contains('Sarah'));

      // Marcus Vance: Fenrir
      expect(testMarcusInterviewer.voiceDisplayName, contains('Fenrir'));
      expect(testMarcusInterviewer.behavioralDirective, contains('Marcus'));
    });

    testWidgets('Scenario 8: Changing difficulty does not change interviewer identity', (tester) async {
      configureViewport(tester);

      final apiService = FakeInterviewerApiService(
        interviewers: [testAlexInterviewer],
        jobs: [testDistJob],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            interviewer: testAlexInterviewer,
            job: testDistJob,
            apiService: apiService,
            audioService: FakeTestHardwareAudioService(),
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Stress/Hardcore difficulty option
      final stressRadio = find.text('Stress / Hardcore');
      expect(stressRadio, findsOneWidget);
      await tester.ensureVisible(stressRadio);
      await tester.tap(stressRadio);
      await tester.pumpAndSettle();

      // Confirm interviewer is STILL Alex Rivera
      final nameFinder = find.byKey(const Key('hardware_interviewer_name'));
      expect(tester.widget<Text>(nameFinder).data, 'Alex Rivera');
    });

    testWidgets('Scenario 9: General practice works without a job description', (tester) async {
      configureViewport(tester);

      final apiService = FakeInterviewerApiService(
        interviewers: [testSarahInterviewer],
        jobs: [],
      );

      FitCheckSession? createdSession;
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            candidate: const FitCheckCandidate(id: 'cand-real-1', fullName: 'Candidate', headline: 'Eng', skills: []),
            interviewer: testSarahInterviewer,
            job: null, // No job provided!
            apiService: apiService,
            audioService: FakeTestHardwareAudioService(),
            onSessionCreated: (s) => createdSession = s,
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final enterBtn = find.byKey(const Key('enter_live_room_button'));
      await tester.ensureVisible(enterBtn);
      await tester.tap(enterBtn);
      await tester.pumpAndSettle();

      expect(apiService.lastStartedInterviewerId, 'sarah-em-001');
      expect(createdSession, isNotNull);
      expect(createdSession!.interviewerId, 'sarah-em-001');
    });

    testWidgets('Scenario 10: Deterministic job-aware recommendations rank appropriately', (tester) async {
      final allInterviewers = [testMarcusInterviewer, testSarahInterviewer, testAlexInterviewer];

      // 1. Distributed Systems job matches Marcus Vance first
      final distMatches = InterviewerRecommendationService.rankInterviewers(
        interviewers: allInterviewers,
        job: testDistJob,
      );
      expect(distMatches.first.interviewer.name, 'Marcus Vance');
      expect(distMatches.first.matchScore, greaterThan(70));
      expect(distMatches.first.headline, contains('Systems'));
      expect(distMatches.first.isTopMatch, isTrue);

      // 2. Full-Stack / Frontend job matches Alex Rivera first
      final fullstackMatches = InterviewerRecommendationService.rankInterviewers(
        interviewers: allInterviewers,
        job: testFrontendJob,
      );
      expect(fullstackMatches.first.interviewer.name, 'Alex Rivera');
      expect(fullstackMatches.first.matchScore, greaterThan(70));
      expect(fullstackMatches.first.isTopMatch, isTrue);

      // 3. Manager job matches Sarah Chen first
      final managerMatches = InterviewerRecommendationService.rankInterviewers(
        interviewers: allInterviewers,
        job: testManagerJob,
      );
      expect(managerMatches.first.interviewer.name, 'Sarah Chen');
      expect(managerMatches.first.matchScore, greaterThan(70));
    });

    testWidgets('Explicit error card is displayed when interviewer fails to load with retry button', (tester) async {
      configureViewport(tester);

      final failingApiService = FakeInterviewerApiService(
        interviewers: [],
        jobs: [],
        shouldFailGetInterviewers: true,
      );

      bool changedInterviewerClicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: HardwareReadinessPage(
            apiService: failingApiService,
            audioService: FakeTestHardwareAudioService(),
            onChangeInterviewer: () => changedInterviewerClicked = true,
            onEnterLiveRoom: () {},
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Error card must be shown
      final errorCard = find.byKey(const Key('hardware_interviewer_error_card'));
      expect(errorCard, findsOneWidget);
      expect(find.text('COULD NOT LOAD INTERVIEWER PERSONA'), findsOneWidget);

      // Tap Choose Another Interviewer
      final chooseBtn = find.byKey(const Key('hardware_choose_another_interviewer_button'));
      expect(chooseBtn, findsOneWidget);
      await tester.ensureVisible(chooseBtn);
      await tester.tap(chooseBtn);
      await tester.pumpAndSettle();
      expect(changedInterviewerClicked, isTrue);
    });
  });
}
