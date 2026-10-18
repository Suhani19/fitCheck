import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fitcheck/core/services/interview_speech_service.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/live_interview_room_page.dart';
import 'package:fitcheck/features/fitcheck/screens/public_landing_page.dart';

class MockFlutterTts extends Fake implements FlutterTts {
  final List<String> spokenTexts = [];
  int speakCallCount = 0;
  int stopCallCount = 0;
  double speechRate = 0.5; // Initially test that initialize updates it to 1.0

  dynamic Function()? _startHandler;
  dynamic Function()? _completionHandler;
  dynamic Function()? _cancelHandler;
  dynamic Function(dynamic)? _errorHandler;

  @override
  void setStartHandler(dynamic Function() handler) => _startHandler = handler;

  @override
  void setCompletionHandler(dynamic Function() handler) => _completionHandler = handler;

  @override
  void setCancelHandler(dynamic Function() handler) => _cancelHandler = handler;

  @override
  void setErrorHandler(dynamic Function(dynamic) handler) => _errorHandler = handler;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    speechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    speakCallCount++;
    spokenTexts.add(text);
    _startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCallCount++;
    return 1;
  }

  void simulateStart() {
    _startHandler?.call();
  }

  void simulateComplete() {
    _completionHandler?.call();
  }

  void simulateCancel() {
    _cancelHandler?.call();
  }

  void simulateError(String msg) {
    _errorHandler?.call(msg);
  }
}

class FakeFitCheckApiService extends Fake implements FitCheckApiService {
  String? nextQuestionText;

  @override
  Future<Map<String, dynamic>> getNextAdaptiveQuestion(
    String sessionId, {
    String? candidateAnswer,
    List<Map<String, dynamic>>? transcriptTurns,
    String? stage,
  }) async {
    return {
      'question': nextQuestionText ?? 'Explain how you handle consensus partition recovery.',
      'stage_decision': {'next_stage': 'deep_dive'},
    };
  }

  @override
  Future<FitCheckSession> endSession(
    String sessionId, {
    List<Map<String, dynamic>> transcript = const [],
  }) async {
    return FitCheckSession(
      id: sessionId,
      candidateId: 'cand-1',
      jobId: 'job-1',
      interviewerId: 'alex',
      status: 'completed',
      channel: 'test-ch',
      difficulty: 'challenging',
      startedAt: '2026-10-18T00:00:00Z',
    );
  }
}

void main() {
  group('A. Public Landing Page CTA Architecture Tests', () {
    testWidgets('Landing page navbar and hero have exactly Try Demo and Start Preparing Free CTAs', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool demoTriggered = false;
      bool startTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: Scaffold(
            body: PublicLandingPage(
              onTryDemo: () => demoTriggered = true,
              onStartPreparing: () => startTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly two CTAs in navbar and hero
      expect(find.text('Try Demo'), findsAtLeastNWidgets(2));
      expect(find.text('Start Preparing Free'), findsAtLeastNWidgets(2));

      // Sign in and Get Started buttons must NOT exist in navbar or hero
      expect(find.byKey(const Key('hero_sign_in_btn')), findsNothing);
      expect(find.byKey(const Key('landing_sign_in_btn')), findsNothing);
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Get Started'), findsNothing);

      // Verify Try Demo button triggers isolated demo flow
      await tester.tap(find.byKey(const Key('hero_try_demo_btn')));
      expect(demoTriggered, isTrue);

      // Verify Start Preparing Free button triggers normal auth flow
      await tester.tap(find.byKey(const Key('hero_start_preparing_btn')));
      expect(startTriggered, isTrue);
    });
  });

  group('B. InterviewSpeechService Deduplication & State Machine Tests', () {
    late MockFlutterTts mockTts;
    late InterviewSpeechService speechService;

    setUp(() {
      mockTts = MockFlutterTts();
      speechService = InterviewSpeechService(tts: mockTts);
    });

    tearDown(() {
      speechService.dispose();
    });

    test('Initializes with natural speech rate (1.0 rate, never slow 0.5 rate)', () async {
      await speechService.initialize();
      expect(mockTts.speechRate, 1.0);
    });

    test('One question causes exactly one playback; repeated call is deduplicated', () async {
      final success1 = await speechService.speakTurn(
        turnId: 'turn_0',
        text: 'Explain consensus protocols.',
      );
      expect(success1, isTrue);
      expect(mockTts.speakCallCount, 1);
      expect(mockTts.spokenTexts.first, 'Explain consensus protocols.');

      // Repeated invocation for same turn without force must be deduplicated
      final success2 = await speechService.speakTurn(
        turnId: 'turn_0',
        text: 'Explain consensus protocols.',
      );
      expect(success2, isFalse);
      expect(mockTts.speakCallCount, 1);
    });

    test('Primary audio activity (Agora) suppresses fallback browser TTS', () async {
      await speechService.markPrimarySpeaking('turn_0', 'Explain consensus protocols.');
      expect(speechService.getTurnAudioState('turn_0'), TurnAudioState.primarySpeaking);

      // Attempting fallback TTS when primary is speaking is immediately suppressed
      final success = await speechService.speakTurn(
        turnId: 'turn_0',
        text: 'Explain consensus protocols.',
      );
      expect(success, isFalse);
      expect(mockTts.speakCallCount, 0);
    });

    test('Primary audio detection immediately stops ongoing fallback TTS', () async {
      // Start fallback TTS
      await speechService.speakTurn(turnId: 'turn_0', text: 'Opening prompt');
      expect(speechService.isSpeaking, isTrue);

      // Agora remote audio arrives: mark primary speaking
      await speechService.markPrimarySpeaking('turn_0');

      // Fallback TTS must have been stopped
      expect(mockTts.stopCallCount, greaterThan(0));
      expect(speechService.getTurnAudioState('turn_0'), TurnAudioState.primarySpeaking);
    });

    test('Manual retry stops existing speech and plays cleanly without duplicate overlap', () async {
      await speechService.speakTurn(turnId: 'turn_0', text: 'Initial prompt');
      expect(mockTts.speakCallCount, 1);

      // User forces retry
      final retrySuccess = await speechService.speakTurn(
        turnId: 'turn_0',
        text: 'Initial prompt',
        force: true,
      );
      expect(retrySuccess, isTrue);
      expect(mockTts.stopCallCount, greaterThan(0));
      expect(mockTts.speakCallCount, 2);
    });
  });

  group('C. FitCheckLiveInterviewRoom Authoritative Audio Lifecycle Tests', () {
    late MockFlutterTts mockTts;
    late InterviewSpeechService speechService;
    late FakeFitCheckApiService apiService;
    final testInterviewer = FitCheckInterviewer(
      id: 'alex',
      name: 'Alex Rivera',
      title: 'Staff Distributed Systems Architect',
      questioningStyle: 'challenging',
      voiceId: 'Fenrir',
    );

    setUp(() {
      mockTts = MockFlutterTts();
      speechService = InterviewSpeechService(tts: mockTts);
      apiService = FakeFitCheckApiService();
    });

    tearDown(() {
      speechService.dispose();
    });

    testWidgets('1. Opening question causes exactly one playback when primary audio path is unavailable', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Session without Agora credentials -> primary path is genuinely unavailable
      final session = FitCheckSession(
        id: 'sess-100',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: '',
        appId: '',
        rtcToken: '',
        sessionPlan: {
          'opening_question': 'Welcome, describe how Raft handles log compaction.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      // Wait for 500ms fallback timer to fire
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(mockTts.speakCallCount, 1);
      expect(mockTts.spokenTexts.first, 'Welcome, describe how Raft handles log compaction.');
    });

    testWidgets('2. Rebuilds and repeated events do not replay the same opening turn', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = FitCheckSession(
        id: 'sess-101',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: '',
        appId: '',
        rtcToken: '',
        sessionPlan: {
          'opening_question': 'Welcome, explain consensus in distributed systems.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(mockTts.speakCallCount, 1);

      // Trigger multiple widget rebuilds
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Audio must NOT replay
      expect(mockTts.speakCallCount, 1);
    });

    testWidgets('3. Primary audio availability prevents browser TTS duplication', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Session with active Agora agent credentials
      final session = FitCheckSession(
        id: 'sess-102',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: 'ch-live-102',
        appId: 'test-app-id',
        rtcToken: 'test-token',
        agentStatus: 'active', // Cloud agent is active on backend
        sessionPlan: {
          'opening_question': 'Explain your strategy for zero-downtime database migration.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      // Wait past connection window
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();

      // Browser TTS must be 0 calls because primary Agora audio is authoritative!
      expect(mockTts.speakCallCount, 0);
    });

    testWidgets('4. Adaptive follow-up causes exactly one speech playback', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = FitCheckSession(
        id: 'sess-103',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: '',
        sessionPlan: {
          'opening_question': 'Describe a microservices failure mode.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(mockTts.speakCallCount, 1);

      // Open text fallback drawer and answer
      await tester.tap(find.textContaining('fallback text response'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cascading circuit breaker timeouts occurred.');
      await tester.pumpAndSettle();

      apiService.nextQuestionText = 'How did you prevent thundering herd on recovery?';
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Opening question (1) + Follow-up question (1) = exactly 2 total plays
      expect(mockTts.speakCallCount, 2);
      expect(mockTts.spokenTexts.last, 'How did you prevent thundering herd on recovery?');
    });

    testWidgets('5. Speak Question Aloud does not replay when already speaking', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = FitCheckSession(
        id: 'sess-104',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: '',
        sessionPlan: {
          'opening_question': 'Explain Paxos vs Raft trade-offs.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Currently speaking (isSpeaking == true)
      expect(mockTts.speakCallCount, 1);

      // Tap Spotlight "Speak Question Aloud" button while currently speaking
      await tester.tap(find.byTooltip('Speak Question Aloud'));
      await tester.pump();

      // Must NOT duplicate speech
      expect(mockTts.speakCallCount, 1);
      expect(find.text('Interviewer is already speaking this question.'), findsOneWidget);
    });

    testWidgets('6. Existing mute, end-call, and audio cleanup behavior still works', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool sessionEnded = false;

      final session = FitCheckSession(
        id: 'sess-105',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'alex',
        status: 'active',
        difficulty: 'challenging',
        startedAt: '2026-10-18T00:00:00Z',
        channel: '',
        sessionPlan: {
          'opening_question': 'Describe high-availability storage.',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: testInterviewer,
            apiService: apiService,
            speechService: speechService,
            onInterviewEnded: (_) => sessionEnded = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Toggle mute
      expect(find.byIcon(Icons.mic), findsOneWidget);
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_off), findsOneWidget);

      // End interview
      await tester.tap(find.byIcon(Icons.call_end));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('End & Evaluate'), findsOneWidget);
      await tester.tap(find.text('End & Evaluate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sessionEnded, isTrue);
      expect(mockTts.stopCallCount, greaterThan(0));
    });
  });
}
