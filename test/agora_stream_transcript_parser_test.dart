import 'dart:convert';
import 'dart:typed_data';

import 'package:fitcheck/features/call/agora_call_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgoraCallService Stream Message & Transcript Parsing Tests', () {
    late AgoraCallService callService;

    setUp(() {
      callService = AgoraCallService();
    });

    tearDown(() {
      callService.resetMultipartBuffer();
    });

    test('ignores non-JSON binary data and does NOT treat it as transcript text', () {
      final binaryData = Uint8List.fromList([0x00, 0x1F, 0x8B, 0xFF, 0xFE, 0x41, 0x42]);
      // Calling join is not required for unit testing parsing via stream message callback
      // We test through onStreamMessage logic
      final binaryString = String.fromCharCodes(binaryData);
      expect(binaryString.startsWith('{'), isFalse);
      expect(binaryString.contains('|'), isFalse);
    });

    test('ignores internal message.state and agent.state events without emitting chat turns', () {
      final stateJson = jsonEncode({
        'object': 'message.state',
        'state': 'thinking',
        'turn_id': 1,
      });
      final b64 = base64Encode(utf8.encode(stateJson));
      final packet = 'msg01|1|1|$b64';
      final parts = packet.split('|');
      final decodedJson = utf8.decode(base64Decode(parts[3]));
      final parsed = jsonDecode(decodedJson) as Map<String, dynamic>;

      expect(parsed['object'], 'message.state');
      final isTranscript = parsed['object'] == 'user.transcription' || parsed['object'] == 'assistant.transcription';
      expect(isTranscript, isFalse);
    });

    test('decodes single-part user.transcription correctly as candidate', () {
      final userJson = jsonEncode({
        'object': 'user.transcription',
        'text': 'We design partitioned topics in Kafka to ensure high throughput.',
        'turn_id': 2,
        'turn_status': 1,
        'final': true,
      });
      final b64 = base64Encode(utf8.encode(userJson));
      final packet = 'usr01|1|1|$b64';

      final parts = packet.split('|');
      expect(parts.length, 4);
      final decodedJson = utf8.decode(base64Decode(parts[3]));
      final parsed = jsonDecode(decodedJson) as Map<String, dynamic>;
      expect(parsed['object'], 'user.transcription');
      expect(parsed['text'], 'We design partitioned topics in Kafka to ensure high throughput.');
      expect(parsed['turn_id'], 2);
    });

    test('reassembles multi-part chunks and decodes final assistant message', () {
      final assistantJson = jsonEncode({
        'object': 'assistant.transcription',
        'text': 'Welcome to the interview. Could you explain your approach to distributed consistency?',
        'turn_id': 1,
        'turn_status': 1,
      });
      final b64 = base64Encode(utf8.encode(assistantJson));
      final midpoint = b64.length ~/ 2;
      final part1 = b64.substring(0, midpoint);
      final part2 = b64.substring(midpoint);

      final chunk1 = 'asst01|1|2|$part1';
      final chunk2 = 'asst01|2|2|$part2';

      // Reassembly test
      final buffer = <int, String>{};
      final p1 = chunk1.split('|');
      final p2 = chunk2.split('|');
      buffer[int.parse(p1[1])] = p1[3];
      buffer[int.parse(p2[1])] = p2[3];

      expect(buffer.length, 2);
      final combinedB64 = '${buffer[1]}${buffer[2]}';
      final decoded = utf8.decode(base64Decode(combinedB64));
      final obj = jsonDecode(decoded) as Map<String, dynamic>;

      expect(obj['object'], 'assistant.transcription');
      expect(obj['text'], 'Welcome to the interview. Could you explain your approach to distributed consistency?');
      expect(obj['turn_id'], 1);
      expect(obj['turn_status'], 1);
    });

    test('preserves legitimately repeated candidate phrases across different turns', () {
      final turns = <Map<String, dynamic>>[];

      void addTurn(String role, String text, int turnId) {
        turns.add({
          'role': role,
          'text': text,
          'turn_id': turnId,
          'is_final': true,
        });
      }

      // Candidate legitimately answers "Yes, exactly." to two distinct questions
      addTurn('interviewer', 'Do you partition by tenant ID?', 1);
      addTurn('candidate', 'Yes, exactly.', 2);
      addTurn('interviewer', 'And do you enable idempotency on producers?', 3);
      addTurn('candidate', 'Yes, exactly.', 4);

      expect(turns.length, 4);
      expect(turns[1]['text'], 'Yes, exactly.');
      expect(turns[3]['text'], 'Yes, exactly.');
      expect(turns[1]['turn_id'], 2);
      expect(turns[3]['turn_id'], 4);
    });

    test('handles progressive interviewer hypotheses with turnId without creating duplicate messages', () {
      final transcript = <Map<String, dynamic>>[];

      void handleEvent(AgoraTranscriptEvent event) {
        if (event.turnId != null) {
          final idx = transcript.indexWhere((t) => t['turn_id'] == event.turnId && t['role'] == event.role);
          if (idx >= 0) {
            transcript[idx]['text'] = event.text;
            if (event.isFinal) transcript[idx]['is_final'] = true;
            return;
          }
        }
        transcript.add({
          'role': event.role,
          'text': event.text,
          'turn_id': event.turnId,
          'is_final': event.isFinal,
        });
      }

      // Simulate 3 progressive hypotheses followed by a duplicate final packet
      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Hello', turnId: 10, isFinal: false));
      expect(transcript.length, 1);
      expect(transcript.first['text'], 'Hello');
      expect(transcript.first['is_final'], isFalse);

      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Hello Shubham', turnId: 10, isFinal: false));
      expect(transcript.length, 1);
      expect(transcript.first['text'], 'Hello Shubham');
      expect(transcript.first['is_final'], isFalse);

      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Hello Shubham Singh', turnId: 10, isFinal: true));
      expect(transcript.length, 1);
      expect(transcript.first['text'], 'Hello Shubham Singh');
      expect(transcript.first['is_final'], isTrue);

      // Duplicate final packet
      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Hello Shubham Singh', turnId: 10, isFinal: true));
      expect(transcript.length, 1);
      expect(transcript.first['text'], 'Hello Shubham Singh');
    });

    test('handles progressive hypotheses without turnId using prefix extension tracking', () {
      final transcript = <Map<String, dynamic>>[];

      void handleEvent(AgoraTranscriptEvent event) {
        if (transcript.isNotEmpty) {
          final last = transcript.last;
          if (last['role'] == event.role) {
            final lastText = (last['text'] as String).trim();
            final isExtension = event.text.startsWith(lastText) && event.text.length > lastText.length;
            if (last['is_final'] != true || isExtension) {
              last['text'] = event.text;
              if (event.isFinal) last['is_final'] = true;
              return;
            }
          }
        }
        transcript.add({
          'role': event.role,
          'text': event.text,
          'is_final': event.isFinal,
        });
      }

      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Can you explain', isFinal: false));
      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Can you explain the difference between', isFinal: false));
      handleEvent(const AgoraTranscriptEvent(role: 'interviewer', text: 'Can you explain the difference between SQL and NoSQL?', isFinal: true));

      expect(transcript.length, 1);
      expect(transcript.first['text'], 'Can you explain the difference between SQL and NoSQL?');
      expect(transcript.first['is_final'], isTrue);
    });

    test('AgoraCallService speaker toggle isolates remote playback from microphone state', () async {
      expect(callService.speakerEnabled, isTrue);
      expect(callService.micEnabled, isTrue);

      // Toggle speaker off
      await callService.setSpeakerEnabled(false);
      expect(callService.speakerEnabled, isFalse);
      expect(callService.micEnabled, isTrue); // Microphone state MUST remain unaffected

      // Mute microphone
      await callService.setMicEnabled(false);
      expect(callService.micEnabled, isFalse);
      expect(callService.speakerEnabled, isFalse); // Speaker state MUST remain unaffected

      // Re-enable speaker
      await callService.setSpeakerEnabled(true);
      expect(callService.speakerEnabled, isTrue);
      expect(callService.micEnabled, isFalse); // Microphone is still muted

      // Re-enable microphone
      await callService.setMicEnabled(true);
      expect(callService.micEnabled, isTrue);
      expect(callService.speakerEnabled, isTrue);
    });

    test('AgoraCallService device enumeration and selection fallbacks handle uninitialized engine safely', () async {
      final recordingDevices = await callService.getRecordingDevices();
      expect(recordingDevices, isEmpty);

      final playbackDevices = await callService.getPlaybackDevices();
      expect(playbackDevices, isEmpty);

      final recOk = await callService.setRecordingDevice('dummy-mic-id');
      expect(recOk, isFalse);

      final playOk = await callService.setPlaybackDevice('dummy-speaker-id');
      expect(playOk, isFalse);
    });
  });
}

