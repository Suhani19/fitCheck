import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fitcheck/core/api/authenticated_api_client.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/live_interview_room_page.dart';

class _MockAuthService implements AuthService {
  @override
  FitCheckUser? get currentUser => const FitCheckUser(uid: 'test-user', email: 'test@fitcheck.io');
  @override
  Stream<FitCheckUser?> get authStateChanges => Stream.value(currentUser);
  @override
  bool get isConfigured => true;
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'test-token';
  @override
  Future<FitCheckUser> signInWithEmailAndPassword({required String email, required String password}) async => currentUser!;
  @override
  Future<FitCheckUser> signUpWithEmailAndPassword({required String email, required String password, String? displayName}) async => currentUser!;
  @override
  Future<FitCheckUser> signInAsDemo() async => currentUser!;
  @override
  Future<void> signOut() async {}
}

void main() {
  group('Interactive Live Interview Widget Tests', () {
    testWidgets('Submitting candidate answer requests adaptive follow-up and updates transcript', (tester) async {
      int nextQuestionCalls = 0;
      String? sentCandidateAnswer;
      List<dynamic>? sentTranscriptTurns;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/next-question')) {
          nextQuestionCalls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentCandidateAnswer = body['candidate_answer'] as String?;
          sentTranscriptTurns = body['transcript_turns'] as List<dynamic>?;

          return http.Response(
            jsonEncode({
              'question': 'How would you handle split-brain partitions in Raft consensus when 2 nodes isolate?',
              'stage': 'technical_deep_dive',
              'contextual_reasoning': 'Candidate mentioned quorum slicing; probing failure mode.',
              'turn_index': 3,
              'transcript': [
                {
                  'role': 'interviewer',
                  'text': 'Welcome, explain consensus in distributed systems.',
                  'turn_index': 0,
                  'stage': 'introduction',
                },
                {
                  'role': 'candidate',
                  'text': sentCandidateAnswer ?? '',
                  'turn_index': 1,
                  'stage': 'introduction',
                },
                {
                  'role': 'interviewer',
                  'text': 'How would you handle split-brain partitions in Raft consensus when 2 nodes isolate?',
                  'turn_index': 2,
                  'stage': 'technical_deep_dive',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('/end')) {
          return http.Response(
            jsonEncode({
              'id': 'sess-interactive-001',
              'candidate_id': 'cand-001',
              'job_id': 'job-001',
              'interviewer_id': 'alex-arch-001',
              'status': 'completed',
              'difficulty': 'challenging',
              'started_at': '2026-10-18T00:00:00Z',
              'ended_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('{"ok": true}', 200, headers: {'content-type': 'application/json'});
      });

      final authClient = AuthenticatedApiClient(authService: _MockAuthService(), httpClient: mockClient);
      final apiService = FitCheckApiService(client: authClient);

      const session = FitCheckSession(
        id: 'sess-interactive-001',
        candidateId: 'cand-001',
        jobId: 'job-001',
        interviewerId: 'alex-arch-001',
        status: 'active',
        difficulty: 'challenging',
        channel: 'fitcheck-sess-interactive-001',
        startedAt: '2026-10-18T00:00:00Z',
        sessionPlan: {
          'opening_question': 'Welcome, explain consensus in distributed systems.',
        },
      );

      const interviewer = FitCheckInterviewer(
        id: 'alex-arch-001',
        name: 'Alex Rivera',
        title: 'Staff Distributed Systems Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FitCheckSession? endedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: FitCheckLiveInterviewRoom(
            session: session,
            interviewer: interviewer,
            apiService: apiService,
            onInterviewEnded: (s) => endedResult = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Opening question displayed in question spotlight and transcript
      expect(find.text('Alex Rivera'), findsWidgets);
      expect(find.text('Welcome, explain consensus in distributed systems.'), findsWidgets);

      // Open fallback text drawer
      expect(find.textContaining('fallback text response'), findsOneWidget);
      await tester.tap(find.textContaining('fallback text response'));
      await tester.pumpAndSettle();

      // Enter candidate response
      final candidateText = 'We use a majority quorum of (N/2)+1 nodes with leader heartbeats to ensure linearizability.';
      await tester.enterText(find.byType(TextField), candidateText);
      await tester.pumpAndSettle();

      // Submit candidate answer
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Verify API was called with candidate answer
      expect(nextQuestionCalls, 1);
      expect(sentCandidateAnswer, candidateText);
      expect(sentTranscriptTurns, isNotNull);

      // Verify the dynamic follow-up is now rendered in the transcript!
      expect(find.text('How would you handle split-brain partitions in Raft consensus when 2 nodes isolate?'), findsWidgets);

      // End interview
      await tester.tap(find.text('End Interview'));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('End Interview Session?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'End & Evaluate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(endedResult, isNotNull);
      expect(endedResult?.status, 'completed');
    });

    testWidgets('Request Clarification button triggers candidate prompt and requests adaptive response', (tester) async {
      int nextQuestionCalls = 0;
      String? sentCandidateAnswer;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/next-question')) {
          nextQuestionCalls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentCandidateAnswer = body['candidate_answer'] as String?;

          return http.Response(
            jsonEncode({
              'question': 'The partition constraint requires less than 50ms latency across 3 availability zones.',
              'stage': 'technical_deep_dive',
              'turn_index': 2,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"ok": true}', 200, headers: {'content-type': 'application/json'});
      });

      final authClient = AuthenticatedApiClient(authService: _MockAuthService(), httpClient: mockClient);
      final apiService = FitCheckApiService(client: authClient);

      const session = FitCheckSession(
        id: 'sess-interactive-002',
        candidateId: 'cand-001',
        jobId: 'job-001',
        interviewerId: 'alex-arch-001',
        status: 'active',
        difficulty: 'challenging',
        channel: 'fitcheck-sess-interactive-002',
        startedAt: '2026-10-18T00:00:00Z',
        sessionPlan: {
          'opening_question': 'How do you design a partitioned database?',
        },
      );

      const interviewer = FitCheckInterviewer(
        id: 'alex-arch-001',
        name: 'Alex Rivera',
        title: 'Staff Distributed Systems Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      tester.view.physicalSize = const Size(1280, 900);
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

      // Tap Request Clarification
      expect(find.text('Request Clarification'), findsOneWidget);
      await tester.tap(find.text('Request Clarification'));
      await tester.pumpAndSettle();

      // Verify that clarification prompt was dispatched
      expect(nextQuestionCalls, 1);
      expect(sentCandidateAnswer, contains('clarify the specific latency constraints'));

      // Verify adaptive response arrived
      expect(find.text('The partition constraint requires less than 50ms latency across 3 availability zones.'), findsWidgets);
    });

    testWidgets('AI adaptive orchestrator failure renders truthful recoverable notice', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/next-question')) {
          return http.Response(
            jsonEncode({'detail': 'Gemini quota exceeded or network disconnect'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"ok": true}', 200, headers: {'content-type': 'application/json'});
      });

      final authClient = AuthenticatedApiClient(authService: _MockAuthService(), httpClient: mockClient);
      final apiService = FitCheckApiService(client: authClient);

      const session = FitCheckSession(
        id: 'sess-interactive-003',
        candidateId: 'cand-001',
        jobId: 'job-001',
        interviewerId: 'alex-arch-001',
        status: 'active',
        difficulty: 'challenging',
        channel: 'fitcheck-sess-interactive-003',
        startedAt: '2026-10-18T00:00:00Z',
        sessionPlan: {
          'opening_question': 'How do you structure database replication?',
        },
      );

      const interviewer = FitCheckInterviewer(
        id: 'alex-arch-001',
        name: 'Alex Rivera',
        title: 'Staff Distributed Systems Architect',
        questioningStyle: 'challenging',
        voiceId: 'Fenrir',
      );

      tester.view.physicalSize = const Size(1280, 900);
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

      // Open fallback text drawer and submit answer
      await tester.tap(find.textContaining('fallback text response'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'We use semi-synchronous replication with Raft.');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send'));
      await tester.pumpAndSettle();

      // Verify truthful error notice appears rather than fake mock answer
      expect(find.textContaining('Interviewer sync issue'), findsOneWidget);
    });
  });
}
