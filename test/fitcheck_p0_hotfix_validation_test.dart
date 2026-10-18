import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/services/hardware_audio_service.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/screens/interviewer_library_page.dart';
import 'package:fitcheck/features/fitcheck/screens/hardware_readiness_page.dart';

class MockAudioRecorder implements AudioRecorder {
  bool isDisposed = false;
  bool isRecordingState = false;
  bool failNextStart = false;
  Completer<void>? pendingAmplitudeCompleter;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    if (isDisposed) throw Exception('Record has not yet been created or has already been disposed.');
    return true;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (isDisposed) throw Exception('Record has not yet been created or has already been disposed.');
    if (failNextStart) throw Exception('Simulated initialization failure');
    isRecordingState = true;
  }

  @override
  Future<String?> stop() async {
    if (isDisposed) throw Exception('Record has not yet been created or has already been disposed.');
    isRecordingState = false;
    return '';
  }

  @override
  Future<bool> isRecording() async {
    if (isDisposed) throw Exception('Record has not yet been created or has already been disposed.');
    return isRecordingState;
  }

  @override
  Future<Amplitude> getAmplitude() async {
    if (isDisposed) throw Exception('Record has not yet been created or has already been disposed.');
    if (pendingAmplitudeCompleter != null) {
      await pendingAmplitudeCompleter!.future;
    }
    return Amplitude(current: -24.0, max: -12.0);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    isRecordingState = false;
  }

  @override
  Future<void> cancel() async {
    isRecordingState = false;
  }

  @override
  Future<bool> isPaused() async => false;

  @override
  Future<List<InputDevice>> listInputDevices() async => [
    const InputDevice(id: 'dev-1', label: 'USB Mic'),
  ];

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async => const Stream.empty();

  @override
  Future<void> setOnConfigChanged(void Function(RecordConfig config)? onConfigChanged) async {}

  @override
  RecordIos? get ios => null;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Stream<RecordState> onStateChanged() => const Stream.empty();

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => const Stream.empty();
}

class MockTestAuth implements AuthService {
  @override
  FitCheckUser? get currentUser => const FitCheckUser(uid: 'u-1', email: 'u@test.com', displayName: 'Jane');
  @override
  Stream<FitCheckUser?> get authStateChanges => Stream.value(currentUser);
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'token';
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
  int sessionCreationCalls = 0;
  bool failNextSessionCreation = false;
  String? lastCreatedJobId;
  String? lastCreatedInterviewerId;

  FakeFitCheckApiService() : super(client: AuthenticatedApiClient(authService: MockTestAuth()));

  @override
  Future<List<FitCheckInterviewer>> listInterviewers() async => [
    const FitCheckInterviewer(
      id: 'sarah-em-001',
      name: 'Sarah Chen',
      title: 'Senior Engineering Manager',
      companyContext: 'Uber Core Infra',
      questioningStyle: 'rigorous',
      voiceId: 'Aoede',
      isPreset: true,
    ),
    const FitCheckInterviewer(
      id: 'alex-lead-001',
      name: 'Alex Rivera',
      title: 'Staff Full-Stack Product Engineer',
      companyContext: 'Vercel / Next.js',
      questioningStyle: 'conversational',
      voiceId: 'Puck',
      isPreset: true,
    ),
  ];

  @override
  Future<List<FitCheckInterviewer>> getInterviewers() async => listInterviewers();

  @override
  Future<List<FitCheckJob>> listJobs() async => [
    const FitCheckJob(
      id: 'job-stripe-001',
      title: 'Staff Distributed Systems Engineer',
      seniority: 'Staff (L6)',
      description: 'Distributed consensus and high throughput systems.',
      requiredSkills: ['Distributed Systems', 'Raft'],
    ),
    const FitCheckJob(
      id: 'job-uber-002',
      title: 'Engineering Manager - Infrastructure',
      seniority: 'Director / EM',
      description: 'Team leadership and technical strategy.',
      requiredSkills: ['Leadership', 'System Design'],
    ),
  ];

  @override
  Future<FitCheckCandidate?> getCurrentCandidate() async => const FitCheckCandidate(
    id: 'cand-test-001',
    fullName: 'Jane Doe',
    headline: 'Senior Backend Engineer',
    skills: ['Go', 'Raft', 'Distributed Systems'],
  );

  @override
  Future<FitCheckSession> startSession({
    required String candidateId,
    required String jobId,
    required String interviewerId,
    String difficulty = 'realistic',
  }) async {
    sessionCreationCalls++;
    lastCreatedJobId = jobId;
    lastCreatedInterviewerId = interviewerId;

    await Future.delayed(const Duration(milliseconds: 60));

    if (failNextSessionCreation) {
      throw Exception('Database lock timeout on session provisioning');
    }

    return FitCheckSession(
      id: 'sess-${DateTime.now().millisecondsSinceEpoch}',
      candidateId: candidateId,
      jobId: jobId,
      interviewerId: interviewerId,
      difficulty: difficulty,
      status: 'active',
      channel: 'channel-test-123',
      startedAt: DateTime.now().toIso8601String(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  group('P0 Issue 1: Interviewer Library Job Dropdown Assertions & State', () {
    testWidgets('1.1 Deduplicates jobs list by canonical ID and renders without assertion', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final duplicateJobs = [
        const FitCheckJob(
          id: 'job-duplicate-123',
          title: 'Distributed Systems Engineer',
          seniority: 'Senior',
          description: 'Systems design',
        ),
        const FitCheckJob(
          id: 'job-duplicate-123', // DUPLICATE ID
          title: 'Distributed Systems Engineer',
          seniority: 'Senior',
          description: 'Systems design duplicate copy',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewerLibraryPage(
              apiService: FakeFitCheckApiService(),
              initialJobs: duplicateJobs,
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown exists and has no assertion
      expect(find.byKey(const Key('library_job_selector_dropdown')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.2 Stale selection (ID not in options) clears cleanly without throwing', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FitCheckJob? notifiedSelectedJob = const FitCheckJob(id: 'stale-deleted-job', title: 'Deleted Job', seniority: 'Senior', description: 'None');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewerLibraryPage(
              apiService: FakeFitCheckApiService(),
              selectedJob: notifiedSelectedJob,
              onSelectJob: (job) => notifiedSelectedJob = job,
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No DropdownButton assertion is thrown
      expect(tester.takeException(), isNull);
      // Stale selection is cleared to null (General Practice)
      expect(notifiedSelectedJob, isNull);
      expect(find.byKey(const Key('library_job_selector_dropdown')), findsOneWidget);
    });

    testWidgets('1.3 Empty job list defaults to General Technical Practice', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewerLibraryPage(
              apiService: FakeFitCheckApiService(),
              initialJobs: const [],
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('General Technical Practice (Browse All)'), findsOneWidget);
    });

    testWidgets('1.4 Normal job selection updates selectedJob and synchronizes', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FitCheckJob? synchronizedJob;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InterviewerLibraryPage(
              apiService: FakeFitCheckApiService(),
              onSelectJob: (j) => synchronizedJob = j,
              onNavigate: (_) {},
              onStartInterview: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap dropdown to select a specific job
      await tester.tap(find.byKey(const Key('library_job_selector_dropdown')));
      await tester.pumpAndSettle();

      // Select Staff Distributed Systems Engineer
      final item = find.text('Staff Distributed Systems Engineer (Staff (L6))').last;
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(synchronizedJob, isNotNull);
      expect(synchronizedJob!.id, 'job-stripe-001');
      expect(tester.takeException(), isNull);
    });
  });

  group('P0 Issue 2: HardwareAudioService Lifecycle & Disposed Notifier Protection', () {
    test('2.1 Dispose prevents ValueNotifier updates during in-flight operations', () async {
      final mockRecorder = MockAudioRecorder();
      final audioService = HardwareAudioService(audioRecorder: mockRecorder, isTestEnv: false);

      // Start mic monitoring
      await audioService.startMicMonitoring();
      expect(audioService.isMonitoringMic, isTrue);

      // Dispose service immediately
      audioService.dispose();
      expect(audioService.isDisposed, isTrue);

      // Trigger sampling on disposed service -> should return 0.0 and NOT throw "used after being disposed"
      final level = await audioService.sampleMicLevel();
      expect(level, 0.0);

      // Trigger stop on disposed service -> should not throw
      await audioService.stopMicMonitoring();
    });

    test('2.2 Repeated dispose and stop calls are safe and idempotent', () async {
      final mockRecorder = MockAudioRecorder();
      final audioService = HardwareAudioService(audioRecorder: mockRecorder, isTestEnv: false);

      await audioService.startMicMonitoring();
      await audioService.stopMicMonitoring();
      await audioService.stopMicMonitoring(); // Repeated stop

      audioService.dispose();
      audioService.dispose(); // Repeated dispose
      expect(audioService.isDisposed, isTrue);
    });

    test('2.3 Recorder initialization failure is handled gracefully without crash', () async {
      final mockRecorder = MockAudioRecorder()..failNextStart = true;
      final audioService = HardwareAudioService(audioRecorder: mockRecorder, isTestEnv: false);

      final success = await audioService.startMicMonitoring();
      expect(success, isFalse);
      expect(audioService.isMonitoringMic, isFalse);
      audioService.dispose();
    });

    testWidgets('2.4 Rapid navigation away from HardwareReadinessPage cleanly releases resources', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRecorder = MockAudioRecorder();
      final audioService = HardwareAudioService(audioRecorder: mockRecorder, isTestEnv: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareReadinessPage(
              audioService: audioService,
              apiService: FakeFitCheckApiService(),
              interviewer: const FitCheckInterviewer(
                id: 'sarah-em-001',
                name: 'Sarah Chen',
                title: 'Senior Engineering Manager',
                companyContext: 'Uber',
                questioningStyle: 'rigorous',
                voiceId: 'Aoede',
                isPreset: true,
              ),
              onEnterLiveRoom: () {},
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly unmount widget (simulating candidate pressing Back or Enter Live Room)
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Navigated Away'))),
      );
      await tester.pumpAndSettle();

      // No exception regarding disposed ValueNotifier or Record
      expect(tester.takeException(), isNull);
    });
  });

  group('P0 Issue 3: Interview Startup Flow & Session Provisioning', () {
    testWidgets('3.1 Enter Live Room creates session and enters live room with selected Sarah Chen', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeApi = FakeFitCheckApiService();
      FitCheckSession? createdSession;
      bool enteredLiveRoom = false;

      const sarah = FitCheckInterviewer(
        id: 'sarah-em-001',
        name: 'Sarah Chen',
        title: 'Senior Engineering Manager',
        companyContext: 'Uber Core Infra',
        questioningStyle: 'rigorous',
        voiceId: 'Aoede',
        isPreset: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareReadinessPage(
              apiService: fakeApi,
              candidate: const FitCheckCandidate(
                id: 'cand-001',
                fullName: 'Alice Walker',
                headline: 'Staff Engineer',
                skills: ['Systems'],
              ),
              interviewer: sarah,
              job: const FitCheckJob(
                id: 'job-uber-002',
                title: 'Engineering Manager',
                seniority: 'EM',
                description: 'Leadership',
              ),
              onSessionCreated: (sess) => createdSession = sess,
              onEnterLiveRoom: () => enteredLiveRoom = true,
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Enter Live Interview Room button
      final enterButton = find.byKey(const Key('enter_live_room_button'));
      expect(enterButton, findsOneWidget);
      await tester.tap(enterButton);
      await tester.pumpAndSettle();

      expect(fakeApi.sessionCreationCalls, 1);
      expect(fakeApi.lastCreatedInterviewerId, 'sarah-em-001');
      expect(fakeApi.lastCreatedJobId, 'job-uber-002');
      expect(createdSession, isNotNull);
      expect(createdSession!.interviewerId, 'sarah-em-001');
      expect(enteredLiveRoom, isTrue);
    });

    testWidgets('3.2 General Practice (null job) passes "general-practice" to backend', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeApi = FakeFitCheckApiService();
      bool entered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareReadinessPage(
              apiService: fakeApi,
              candidate: const FitCheckCandidate(
                id: 'cand-001',
                fullName: 'Bob Smith',
                headline: 'Backend Engineer',
                skills: ['Distributed Systems'],
              ),
              interviewer: const FitCheckInterviewer(
                id: 'alex-lead-001',
                name: 'Alex Rivera',
                title: 'Staff Full-Stack Product Engineer',
                companyContext: 'Vercel',
                questioningStyle: 'conversational',
                voiceId: 'Puck',
                isPreset: true,
              ),
              job: null, // General practice
              onSessionCreated: (_) {},
              onEnterLiveRoom: () => entered = true,
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enter_live_room_button')));
      await tester.pumpAndSettle();

      expect(fakeApi.lastCreatedJobId, 'general-practice');
      expect(fakeApi.lastCreatedInterviewerId, 'alex-lead-001');
      expect(entered, isTrue);
    });

    testWidgets('3.3 Prevents duplicate session creation on repeated button clicks', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeApi = FakeFitCheckApiService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareReadinessPage(
              apiService: fakeApi,
              candidate: const FitCheckCandidate(
                id: 'cand-001',
                fullName: 'Alice',
                headline: 'Engineer',
                skills: ['Go'],
              ),
              interviewer: const FitCheckInterviewer(
                id: 'sarah-em-001',
                name: 'Sarah Chen',
                title: 'EM',
                companyContext: 'Uber',
                questioningStyle: 'rigorous',
                voiceId: 'Aoede',
                isPreset: true,
              ),
              onSessionCreated: (_) {},
              onEnterLiveRoom: () {},
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final enterButton = find.byKey(const Key('enter_live_room_button'));
      // Rapid multiple taps
      await tester.tap(enterButton);
      await tester.tap(enterButton);
      await tester.tap(enterButton);
      await tester.pumpAndSettle();

      // Only one call made!
      expect(fakeApi.sessionCreationCalls, 1);
    });

    testWidgets('3.4 Failed session creation displays actionable error snackbar with retry', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeApi = FakeFitCheckApiService()..failNextSessionCreation = true;
      bool enteredLiveRoom = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareReadinessPage(
              apiService: fakeApi,
              candidate: const FitCheckCandidate(
                id: 'cand-001',
                fullName: 'Alice',
                headline: 'Engineer',
                skills: ['Go'],
              ),
              interviewer: const FitCheckInterviewer(
                id: 'alex-lead-001',
                name: 'Alex Rivera',
                title: 'Staff Full-Stack',
                companyContext: 'Vercel',
                questioningStyle: 'conversational',
                voiceId: 'Puck',
                isPreset: true,
              ),
              onSessionCreated: (_) {},
              onEnterLiveRoom: () => enteredLiveRoom = true,
              onBackToDashboard: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('enter_live_room_button')));
      await tester.pumpAndSettle();

      // Did not enter live room
      expect(enteredLiveRoom, isFalse);

      // Visible actionable error shown
      expect(find.byKey(const Key('hardware_session_creation_error_snack')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now fix failure and tap Retry
      fakeApi.failNextSessionCreation = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(enteredLiveRoom, isTrue);
      expect(fakeApi.sessionCreationCalls, 2);
    });
  });
}
