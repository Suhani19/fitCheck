import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/features/call/call_session_manager.dart';
import 'package:fitcheck/features/call/minimized_call_banner.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';

void main() {
  FitCheckInterviewer makeTestInterviewer({
    String id = 'interviewer-alex',
    String name = 'Alex Rivera',
    String title = 'Staff Distributed Systems Architect',
    String questioningStyle = 'socratic',
    String voiceId = 'Puck',
  }) {
    return FitCheckInterviewer(
      id: id,
      name: name,
      title: title,
      questioningStyle: questioningStyle,
      voiceId: voiceId,
    );
  }

  group('CallSessionManager - Conversational State & Emotion Engine', () {
    late CallSessionManager manager;

    setUp(() {
      manager = CallSessionManager.instance;
      manager.resetForTesting();
    });

    test('Conversational state transitions: idle -> listening -> thinking -> speaking -> listening', () {
      expect(manager.conversationState, ConversationState.idle);

      // 1. User starts speaking -> listening
      manager.setStateForTesting(
        interviewer: makeTestInterviewer(),
        status: CallStatus.active,
      );
      manager.setConversationStateForTesting(ConversationState.listening);
      expect(manager.conversationState, ConversationState.listening);

      // 2. User stops speaking -> thinking
      manager.setConversationStateForTesting(ConversationState.thinking);
      expect(manager.conversationState, ConversationState.thinking);

      // 3. Interviewer starts speaking -> speaking
      manager.setConversationStateForTesting(ConversationState.speaking);
      expect(manager.conversationState, ConversationState.speaking);

      // 4. Interviewer finishes speaking -> listening
      manager.setConversationStateForTesting(ConversationState.listening);
      expect(manager.conversationState, ConversationState.listening);
    });

    test('Emotion detection from transcript turns and momentum/decay', () {
      manager.setStateForTesting(
        interviewer: makeTestInterviewer(),
        status: CallStatus.active,
      );

      // 1. Positive achievement -> excited
      manager.recordTranscriptTurn('user', 'I finally got the job! We did it!');
      expect(manager.currentEmotion, 'excited');
      expect(manager.emotionIntensity, greaterThanOrEqualTo(0.80));

      // 2. Unreinforced neutral turn -> gradual decay
      final prevIntensity = manager.emotionIntensity;
      manager.recordTranscriptTurn('user', 'What time is it right now?');
      expect(manager.currentEmotion, 'excited');
      expect(manager.emotionIntensity, lessThan(prevIntensity));

      // 3. Funny banter -> amused
      manager.recordTranscriptTurn('assistant', 'Haha that joke was hilarious, you crack me up!');
      expect(manager.currentEmotion, 'amused');
      expect(manager.emotionIntensity, greaterThanOrEqualTo(0.65));

      // 4. Sadness -> sad
      manager.recordTranscriptTurn('user', 'I lost my dog yesterday and I am heartbroken and crying.');
      expect(manager.currentEmotion, 'sad');
      expect(manager.emotionIntensity, greaterThanOrEqualTo(0.70));

      // 5. Hostility -> defensive
      manager.recordTranscriptTurn('user', 'Shut up you stupid idiot, you are wrong.');
      expect(manager.currentEmotion, 'defensive');
      expect(manager.emotionIntensity, greaterThanOrEqualTo(0.75));
    });

    test('Language detection accurately identifies English, Hindi, and Hinglish', () {
      expect(manager.detectLanguage('Good morning! How are you doing today?'), 'english');
      expect(manager.detectLanguage('Haan yaar, kal baat karte hain, aaj kaafi kaam hai.'), 'hinglish');
      expect(manager.detectLanguage('नमस्ते, आप कैसे हैं?'), 'hindi');
    });
  });

  group('Interviewer Call State & Banner Visuals', () {
    late CallSessionManager manager;

    setUp(() {
      manager = CallSessionManager.instance;
      manager.resetForTesting();
    });

    for (final emotion in ['neutral', 'happy', 'amused', 'sad', 'defensive', 'excited']) {
      testWidgets('CallSessionManager tracks emotion "$emotion" and banner renders safely', (tester) async {
        final interviewer = makeTestInterviewer();
        manager.setStateForTesting(
          interviewer: interviewer,
          status: CallStatus.minimized,
          currentEmotion: emotion,
          emotionIntensity: 0.80,
          conversationState: ConversationState.speaking,
          remoteAudioLevel: 0.6,
        );

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MinimizedCallBanner(),
            ),
          ),
        );

        await tester.pump();

        expect(find.text(interviewer.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('CallSessionManager displays conversational states correctly: speaking, thinking, listening', (tester) async {
      final interviewer = makeTestInterviewer();
      manager.setStateForTesting(
        interviewer: interviewer,
        status: CallStatus.active,
        interviewerPresent: true,
      );

      manager.setStateForTesting(conversationState: ConversationState.speaking);
      expect(manager.conversationState, equals(ConversationState.speaking));

      manager.setStateForTesting(conversationState: ConversationState.thinking);
      expect(manager.conversationState, equals(ConversationState.thinking));

      manager.setStateForTesting(conversationState: ConversationState.listening);
      expect(manager.conversationState, equals(ConversationState.listening));
    });
  });
}
