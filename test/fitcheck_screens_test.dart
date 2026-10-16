import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_auth_page.dart';
import 'package:fitcheck/features/fitcheck/candidate_profile_page.dart';
import 'package:fitcheck/features/fitcheck/job_selection_page.dart';
import 'package:fitcheck/features/fitcheck/difficulty_selection_page.dart';
import 'package:fitcheck/features/fitcheck/live_interview_room_page.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_evaluation_page.dart';

class MockAuthServiceForWidgetTest implements AuthService {
  FitCheckUser? _user;
  String? token = 'mock_valid_id_token';

  MockAuthServiceForWidgetTest({FitCheckUser? user}) : _user = user;

  @override
  FitCheckUser? get currentUser => _user;

  @override
  Stream<FitCheckUser?> get authStateChanges => Stream.value(_user);

  @override
  bool get isConfigured => true;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => token;

  @override
  Future<FitCheckUser> signInWithEmailAndPassword({required String email, required String password}) async {
    _user = FitCheckUser(uid: 'test-user-1', email: email);
    return _user!;
  }

  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({required String email, required String password, String? displayName}) async {
    _user = FitCheckUser(uid: 'test-user-1', email: email, displayName: displayName);
    return _user!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
  }
}

void main() {
  group('FitCheck End-to-End Flutter Experience Tests', () {
    testWidgets('FitCheckAuthPage signs in and notifies callback', (tester) async {
      final auth = MockAuthServiceForWidgetTest();
      bool authenticated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckAuthPage(
            authService: auth,
            onAuthenticated: () => authenticated = true,
          ),
        ),
      );

      expect(find.text('FitCheck'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'candidate@test.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(authenticated, isTrue);
      expect(auth.currentUser?.email, 'candidate@test.com');
    });

    testWidgets('CandidateProfilePage lists candidates and selects one', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/candidates') {
          return http.Response(
            jsonEncode([
              {
                'id': 'cand-1',
                'full_name': 'Kavita Raman',
                'headline': 'Lead Distributed Systems Engineer',
                'skills': ['Go', 'Kafka'],
                'work_experience': [],
                'projects': [],
              }
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);
      FitCheckCandidate? selectedCand;

      await tester.pumpWidget(
        MaterialApp(
          home: CandidateProfilePage(
            apiService: apiService,
            onCandidateSelected: (cand) => selectedCand = cand,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kavita Raman'), findsOneWidget);
      expect(find.text('Lead Distributed Systems Engineer'), findsOneWidget);

      await tester.tap(find.text('Kavita Raman'));
      await tester.pumpAndSettle();

      expect(selectedCand, isNotNull);
      expect(selectedCand?.fullName, 'Kavita Raman');
    });

    testWidgets('JobSelectionPage lists jobs and selects target role', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/jobs') {
          return http.Response(
            jsonEncode([
              {
                'id': 'job-1',
                'title': 'Principal Architect',
                'seniority': 'principal',
                'description': 'Lead global streaming architecture.',
                'required_skills': ['Go', 'Kafka'],
                'competencies': [
                  {'name': 'High-Throughput Streaming', 'criteria': ['Kafka partitioning']}
                ],
              }
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);
      FitCheckJob? selectedJob;

      await tester.pumpWidget(
        MaterialApp(
          home: JobSelectionPage(
            apiService: apiService,
            onJobSelected: (job) => selectedJob = job,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Principal Architect (principal)'), findsOneWidget);

      await tester.tap(find.text('Principal Architect (principal)'));
      await tester.pumpAndSettle();

      expect(selectedJob, isNotNull);
      expect(selectedJob?.title, 'Principal Architect');
    });

    testWidgets('DifficultyAndPreparationPage presents 4 modes and launches session', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/sessions') {
          return http.Response(
            jsonEncode({
              'id': 'sess-100',
              'candidate_id': 'cand-1',
              'job_id': 'job-1',
              'interviewer_id': 'marcus-arch-001',
              'difficulty': 'challenging',
              'status': 'active',
              'channel': 'fitcheck-sess-100',
              'started_at': '2026-10-15T00:00:00Z',
              'session_plan': {
                'opening_question': 'Welcome Kavita, walk me through Kafka partitioning.',
              },
            }),
            201,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);
      FitCheckSession? launchedSession;

      const candidate = FitCheckCandidate(id: 'cand-1', fullName: 'Kavita Raman');
      const job = FitCheckJob(id: 'job-1', title: 'Principal Architect', seniority: 'principal', description: '');
      const interviewer = FitCheckInterviewer(
        id: 'marcus-arch-001',
        name: 'Marcus Vance',
        title: 'Principal Distributed Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DifficultyAndPreparationPage(
            candidate: candidate,
            job: job,
            interviewer: interviewer,
            apiService: apiService,
            onSessionLaunched: (s) => launchedSession = s,
          ),
        ),
      );

      expect(find.text('Lenient Mode'), findsOneWidget);
      expect(find.text('Realistic Mode'), findsOneWidget);

      // Scroll to Challenging mode and select it
      await tester.scrollUntilVisible(find.text('Challenging Mode'), 200);
      await tester.tap(find.text('Challenging Mode'));
      await tester.pumpAndSettle();

      // Scroll to Begin button and tap
      await tester.scrollUntilVisible(find.text('Begin Real-Time Voice Interview'), 200);
      await tester.tap(find.text('Begin Real-Time Voice Interview'));
      await tester.pumpAndSettle();

      expect(launchedSession, isNotNull);
      expect(launchedSession?.id, 'sess-100');
    });

    testWidgets('LiveInterviewRoom displays opening question and ends session', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/sessions/sess-100/end') {
          return http.Response(
            jsonEncode({
              'id': 'sess-100',
              'candidate_id': 'cand-1',
              'job_id': 'job-1',
              'interviewer_id': 'marcus-arch-001',
              'difficulty': 'realistic',
              'status': 'ended',
              'channel': 'fitcheck-sess-100',
              'started_at': '2026-10-15T00:00:00Z',
              'ended_at': '2026-10-15T00:20:00Z',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);
      FitCheckSession? endedSessionResult;

      const session = FitCheckSession(
        id: 'sess-100',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'marcus-arch-001',
        difficulty: 'realistic',
        status: 'active',
        channel: 'fitcheck-sess-100',
        startedAt: '2026-10-15T00:00:00Z',
        sessionPlan: {
          'opening_question': 'Welcome Kavita, walk me through Kafka partitioning.',
        },
      );

      const interviewer = FitCheckInterviewer(
        id: 'marcus-arch-001',
        name: 'Marcus Vance',
        title: 'Principal Distributed Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: interviewer,
            apiService: apiService,
            onInterviewEnded: (s) => endedSessionResult = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsWidgets);
      expect(find.text('Welcome Kavita, walk me through Kafka partitioning.'), findsOneWidget);
      expect(find.text('Interviewer • CHALLENGING'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('STAGE: INTRODUCTION'), findsOneWidget);

      // Verify controls
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Speaker On'), findsOneWidget);
      expect(find.text('Audio Devices'), findsOneWidget);
      expect(find.text('Audio Call'), findsOneWidget);

      // Verify Speaker toggle toggles UI state
      await tester.tap(find.text('Speaker On'));
      await tester.pumpAndSettle();
      expect(find.text('Speaker Off'), findsOneWidget);
      await tester.tap(find.text('Speaker Off'));
      await tester.pumpAndSettle();
      expect(find.text('Speaker On'), findsOneWidget);

      // Verify Mute toggle toggles UI state
      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(find.text('Unmute'), findsOneWidget);
      await tester.tap(find.text('Unmute'));
      await tester.pumpAndSettle();
      expect(find.text('Mute'), findsOneWidget);

      // Verify Audio Devices settings modal
      await tester.tap(find.text('Audio Devices'));
      await tester.pumpAndSettle();
      expect(find.text('Audio Devices & Settings'), findsOneWidget);
      expect(find.text('Microphone (Audio Input)'), findsOneWidget);
      expect(find.text('Speaker (Audio Output)'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Audio Devices & Settings'), findsNothing);

      // Tap End Interview
      await tester.tap(find.text('End Interview'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('End Interview Session?'), findsOneWidget);
      await tester.tap(find.text('End & Evaluate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(endedSessionResult, isNotNull);
      expect(endedSessionResult?.status, 'ended');
    });

    testWidgets('LiveInterviewRoom responsive layout switches between desktop and compact viewports', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final apiService = FitCheckApiService(
        client: AuthenticatedApiClient(authService: auth),
      );
      const session = FitCheckSession(
        id: 'sess-resp-1',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'marcus-arch-001',
        difficulty: 'challenging',
        status: 'active',
        channel: 'fitcheck-sess-resp-1',
        startedAt: '2026-10-15T00:00:00Z',
        sessionPlan: {
          'opening_question': 'Welcome, please explain your architecture approach.',
        },
      );
      const interviewer = FitCheckInterviewer(
        id: 'marcus-arch-001',
        name: 'Marcus Vance',
        title: 'Principal Distributed Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );
      const candidate = FitCheckCandidate(
        id: 'cand-1',
        fullName: 'Kavita Raman',
      );

      // 1. Desktop Viewport (1200 x 800)
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: interviewer,
            candidate: candidate,
            apiService: apiService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kavita Raman (You)'), findsOneWidget);
      expect(find.text('Interviewer • CHALLENGING'), findsOneWidget);
      expect(find.text('LATEST QUESTION'), findsOneWidget);

      // 2. Mobile Viewport (400 x 700)
      tester.view.physicalSize = const Size(400, 700);
      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: interviewer,
            candidate: candidate,
            apiService: apiService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In compact mode, participant labels are condensed
      expect(find.text('You'), findsWidgets);
      expect(find.text('Mute'), findsOneWidget);
    });

    testWidgets('FitCheckEvaluationReportPage displays scores and preparation plan', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/evaluations/sess-100') {
          return http.Response(
            jsonEncode({
              'id': 'eval-1',
              'session_id': 'sess-100',
              'user_id': 'user-1',
              'overall_score': 4.2,
              'overall_recommendation': 'Hire',
              'summary_verdict': 'Demonstrated strong depth in distributed state machines and partition keys.',
              'competency_scores': [
                {
                  'competency_name': 'High-Throughput Streaming',
                  'score': 4.5,
                  'status': 'evaluated',
                  'explanation': 'Clear articulation of Kafka key hashing strategies.',
                  'evidence_citations': [
                    {'quote': 'We partitioned by customer ID with murmur3', 'verified': true}
                  ],
                }
              ],
              'observed_strengths': ['Streaming architecture', 'Consensus protocols'],
              'technical_gaps': [],
              'preparation_recommendations': [
                'Review zero-downtime database schema migration strategies.',
              ],
              'created_at': '2026-10-15T00:25:00Z',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);
      bool doneClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckEvaluationReportPage(
            sessionId: 'sess-100',
            apiService: apiService,
            onDone: () => doneClicked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hire'), findsOneWidget);
      expect(find.text('4.2 / 5.0'), findsOneWidget);
      expect(find.text('High-Throughput Streaming'), findsOneWidget);
      expect(find.text('Review zero-downtime database schema migration strategies.'), findsOneWidget);

      await tester.tap(find.text('Done'));
      expect(doneClicked, isTrue);
    });

    testWidgets('FitCheckEvaluationReportPage displays Insufficient Signal instead of 0.0/5.0 on Insufficient Evidence', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final mockHttp = MockClient((request) async {
        if (request.url.path == '/api/v1/evaluations/sess-empty') {
          return http.Response(
            jsonEncode({
              'id': 'eval-empty',
              'session_id': 'sess-empty',
              'user_id': 'user-1',
              'overall_score': 0.0,
              'overall_recommendation': 'Insufficient Evidence',
              'summary_verdict': 'Session concluded with no candidate verbal responses recorded.',
              'competency_scores': [
                {
                  'competency_name': 'System Architecture',
                  'score': 0.0,
                  'status': 'insufficient_evidence',
                  'explanation': 'No candidate responses were recorded during the session.',
                  'evidence_citations': [],
                }
              ],
              'observed_strengths': [],
              'technical_gaps': [],
              'preparation_recommendations': [
                'Ensure your microphone is connected and browser permissions are granted before starting the interview.',
              ],
              'created_at': '2026-10-15T00:25:00Z',
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final client = AuthenticatedApiClient(authService: auth, httpClient: mockHttp);
      final apiService = FitCheckApiService(client: client);

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckEvaluationReportPage(
            sessionId: 'sess-empty',
            apiService: apiService,
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insufficient Evidence'), findsWidgets);
      expect(find.text('No Score (Insufficient Signal)'), findsOneWidget);
      expect(find.text('0.0 / 5.0'), findsNothing);
      expect(find.text('Ensure your microphone is connected and browser permissions are granted before starting the interview.'), findsOneWidget);
    });

    testWidgets('LiveInterviewRoom hydrates existing transcript without duplicating opening question', (tester) async {
      final auth = MockAuthServiceForWidgetTest(
        user: const FitCheckUser(uid: 'user-1', email: 'user@test.com'),
      );
      final apiService = FitCheckApiService(
        client: AuthenticatedApiClient(authService: auth),
      );

      const existingTranscript = [
        {
          'role': 'interviewer',
          'text': 'Initial question about Kafka partitioning.',
          'turn_id': 1,
          'turn_index': 0,
        },
        {
          'role': 'candidate',
          'text': 'We partition by tenant ID using a consistent hashing algorithm.',
          'turn_id': 2,
          'turn_index': 1,
        },
      ];

      const session = FitCheckSession(
        id: 'sess-hydrated',
        candidateId: 'cand-1',
        jobId: 'job-1',
        interviewerId: 'marcus-arch-001',
        difficulty: 'realistic',
        status: 'active',
        channel: 'fitcheck-sess-hydrated',
        startedAt: '2026-10-15T00:00:00Z',
        transcript: existingTranscript,
        sessionPlan: {
          'opening_question': 'Initial question about Kafka partitioning.',
        },
      );

      const interviewer = FitCheckInterviewer(
        id: 'marcus-arch-001',
        name: 'Marcus Vance',
        title: 'Principal Distributed Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: interviewer,
            apiService: apiService,
            onInterviewEnded: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Opening question should appear once, not twice
      expect(find.text('Initial question about Kafka partitioning.'), findsOneWidget);
      // Candidate answer should be present
      expect(find.text('We partition by tenant ID using a consistent hashing algorithm.'), findsOneWidget);
    });
  });
}
