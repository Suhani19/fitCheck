import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/features/call/agora_call_service.dart';
import 'package:fitcheck/features/call/call_session_manager.dart';
import 'package:fitcheck/features/call/call_sound_service.dart';
import 'package:fitcheck/features/call/minimized_call_banner.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';

import 'package:fitcheck/features/call/runtime_api.dart';
class MockSlowAgoraService extends AgoraCallService {
  final Completer<void> leaveCompleter = Completer<void>();
  bool leaveCalled = false;

  @override
  Future<void> leave() async {
    leaveCalled = true;
    await leaveCompleter.future;
  }
}

class MockAgoraServiceWithCallbacks extends AgoraCallService {
  void Function()? onJoinedCallback;
  void Function(int remoteUid)? onRemoteUserJoinedCallback;

  @override
  Future<void> join({
    required String appId,
    required String token,
    required String channel,
    required int uid,
    required void Function() onJoined,
    required void Function(int remoteUid) onRemoteUserJoined,
    required void Function(int remoteUid) onRemoteUserLeft,
    required void Function({required int uid, required int volume}) onAudioVolume,
    required void Function(String message) onError,
    void Function(String role, String text)? onTranscriptTurn,
    void Function(AgoraTranscriptEvent event)? onTranscriptEvent,
  }) async {
    onJoinedCallback = onJoined;
    onRemoteUserJoinedCallback = onRemoteUserJoined;
  }
}

class MockRuntimeApi extends RuntimeApi {
  @override
  Future<RuntimeSession> createSession({
    required String interviewerId,
    String userId = 'default_user',
  }) async {
    return RuntimeSession(
      sessionId: 'test-session-123',
      agentId: 'agent-123',
      interviewerId: interviewerId,
      interviewerName: 'Marcus Vance',
      channel: 'test-channel',
      uid: 1001,
      rtcToken: 'mock-token',
      appId: 'mock-app-id',
    );
  }

  @override
  Future<Map<String, dynamic>> endSession({
    required String sessionId,
    List<Map<String, String>> transcript = const [],
  }) async {
    return {'status': 'ok'};
  }
}

void main() {
  const testInterviewer = FitCheckInterviewer(
    id: 'char-test-01',
    name: 'Alex Rivera',
    title: 'Staff Distributed Systems Architect',
    questioningStyle: 'socratic',
    voiceId: 'Puck',
  );

  group('CallSessionManager - Audio Lifecycle & Teardown', () {
    test('initial state is idle', () {
      final manager = CallSessionManager.instance;
      expect(manager.status, equals(CallStatus.idle));
      expect(manager.isCallActive, isFalse);
      expect(manager.isMinimized, isFalse);
      expect(manager.callSeconds, equals(0));
      expect(manager.formattedCallTime, equals('00:00'));
    });

    test('records transcript turns properly', () {
      final manager = CallSessionManager.instance;
      manager.recordTranscriptTurn('user', 'Hello there');
      manager.recordTranscriptTurn('assistant', 'Hey! Welcome.');
    });

    test('1. connecting starts the ringing sound', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      manager.setStatusForTesting(CallStatus.connecting);

      expect(manager.soundService.isPlayingConnecting, isTrue);
      expect(manager.soundService.connectingPlayCount, equals(1));
      manager.resetForTesting();
    });

    test('2. connecting -> active stops ringing and plays connected sound exactly once', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      manager.setStatusForTesting(CallStatus.connecting);
      expect(manager.soundService.isPlayingConnecting, isTrue);

      manager.setStatusForTesting(CallStatus.active);
      expect(manager.soundService.isPlayingConnecting, isFalse);
      expect(manager.soundService.connectedPlayCount, equals(1));
      manager.resetForTesting();
    });

    test('3. repeated active events do not replay the connected sound', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      manager.setStatusForTesting(CallStatus.connecting);
      manager.setStatusForTesting(CallStatus.active);
      expect(manager.soundService.connectedPlayCount, equals(1));

      // Attempt repeated active transition directly
      manager.setStatusForTesting(CallStatus.active);
      expect(manager.soundService.connectedPlayCount, equals(1));

      // Cycle minimized -> active
      manager.setStatusForTesting(CallStatus.minimized);
      manager.setStatusForTesting(CallStatus.active);
      expect(manager.soundService.connectedPlayCount, equals(1));
      manager.resetForTesting();
    });

    test('4. active -> ending plays the end sound', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.active,
      );

      await manager.endCall();
      expect(manager.soundService.callEndedPlayCount, equals(1));
      expect(manager.status, equals(CallStatus.idle));
      manager.resetForTesting();
    });

    test('5. connecting -> ending also plays the end sound', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.connecting,
      );

      await manager.endCall();
      expect(manager.soundService.callEndedPlayCount, equals(1));
      expect(manager.soundService.isPlayingConnecting, isFalse);
      expect(manager.status, equals(CallStatus.idle));
      manager.resetForTesting();
    });

    test('6. minimized -> ending plays the end sound', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.minimized,
      );

      await manager.endCall();
      expect(manager.soundService.callEndedPlayCount, equals(1));
      expect(manager.status, equals(CallStatus.idle));
      manager.resetForTesting();
    });

    test('7. end sound plays without waiting for Agora teardown', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      final slowAgora = MockSlowAgoraService();
      manager.callServiceForTesting = slowAgora;
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.active,
      );

      final endFuture = manager.endCall();
      await endFuture;

      // End sound was already triggered immediately
      expect(manager.soundService.callEndedPlayCount, equals(1));
      // Local state is already idle
      expect(manager.status, equals(CallStatus.idle));
      // Agora leave was dispatched asynchronously and is still pending
      expect(slowAgora.leaveCalled, isTrue);
      expect(slowAgora.leaveCompleter.isCompleted, isFalse);

      // Now complete the slow Agora teardown
      slowAgora.leaveCompleter.complete();
      manager.callServiceForTesting = AgoraCallService();
      manager.resetForTesting();
    });

    test('8. existing call teardown behavior remains unchanged', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      manager.recordTranscriptTurn('user', 'Hello');
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.active,
        seconds: 42,
        interviewerSpeaking: true,
      );

      final statesObserved = <CallStatus>[];
      void listener() {
        statesObserved.add(manager.status);
      }
      manager.addListener(listener);

      await manager.endCall();

      expect(statesObserved.contains(CallStatus.connecting), isFalse);
      expect(statesObserved.contains(CallStatus.ending), isTrue);
      expect(manager.status, equals(CallStatus.idle));
      expect(manager.activeInterviewer, isNull);
      expect(manager.currentSession, isNull);
      expect(manager.callSeconds, equals(0));
      expect(manager.interviewerSpeaking, isFalse);

      // Idempotent secondary call
      await manager.endCall();
      expect(manager.status, equals(CallStatus.idle));

      manager.removeListener(listener);
      manager.resetForTesting();
    });

    test('startCall is rejected when status is ending or ended', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.ending,
      );

      // Attempt to start call while ending
      await manager.startCall(testInterviewer);
      // Status must remain ending, not revert to connecting
      expect(manager.status, equals(CallStatus.ending));

      manager.resetForTesting();
    });

    test('real runtime call flow: connecting -> onJoined keeps ringing -> onRemoteUserJoined plays connected chime once', () async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      final mockAgora = MockAgoraServiceWithCallbacks();
      final mockApi = MockRuntimeApi();
      manager.callServiceForTesting = mockAgora;
      manager.runtimeApiForTesting = mockApi;

      // 1. Start call
      await manager.startCall(testInterviewer);
      expect(manager.status, equals(CallStatus.connecting));
      expect(manager.soundService.isPlayingConnecting, isTrue);
      expect(manager.soundService.connectedPlayCount, equals(0));

      // 2. Local Agora connection established (onJoined)
      mockAgora.onJoinedCallback?.call();
      // Ringing should STILL be playing because agent has not joined yet!
      expect(manager.status, equals(CallStatus.connecting));
      expect(manager.soundService.isPlayingConnecting, isTrue);
      expect(manager.soundService.connectedPlayCount, equals(0));

      // 3. Remote agent joins the channel (onRemoteUserJoined)
      mockAgora.onRemoteUserJoinedCallback?.call(9999);
      // Ringing stops, connected chime plays once, status becomes active!
      expect(manager.status, equals(CallStatus.active));
      expect(manager.soundService.isPlayingConnecting, isFalse);
      expect(manager.soundService.connectedPlayCount, equals(1));

      // 4. Repeated remote user events do not replay connected chime
      mockAgora.onRemoteUserJoinedCallback?.call(9999);
      expect(manager.soundService.connectedPlayCount, equals(1));

      // Cleanup
      manager.callServiceForTesting = AgoraCallService();
      manager.runtimeApiForTesting = RuntimeApi();
      manager.resetForTesting();
    });

    test('CallSoundService handles all lifecycle calls gracefully without throwing', () async {
      final soundService = CallSoundService.noop();
      await soundService.playConnecting();
      await soundService.stopConnecting();
      await soundService.playConnected();
      await soundService.playCallEnded();
      await soundService.stopAll();
      soundService.dispose();
    });
  });

  group('MinimizedCallBanner Widget', () {
    testWidgets('renders nothing when not minimized or idle', (tester) async {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MinimizedCallBanner(),
          ),
        ),
      );

      expect(find.byType(MinimizedCallBanner), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('In call'), findsNothing);
    });

    testWidgets('renders character name and time when minimized', (tester) async {
      final manager = CallSessionManager.instance;
      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.minimized,
        seconds: 75,
        interviewerSpeaking: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MinimizedCallBanner(),
          ),
        ),
      );

      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.textContaining('01:15'), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);

      manager.resetForTesting();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MinimizedCallBanner(),
          ),
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });
}
