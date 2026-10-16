import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/features/call/runtime_api.dart';

void main() {
  test('RuntimeSession parses session response with app_id', () {
    final json = {
      'status': 'started',
      'agent_id': 'agent_123',
      'interviewer_id': 'alex-lead-001',
      'interviewer_name': 'Alex Rivera',
      'channel': 'fitcheck-alex-channel',
      'uid': 1001,
      'rtc_token': 'test_token',
      'app_id': 'agora_app_123',
    };

    final session = RuntimeSession.fromJson(json);

    expect(session.agentId, 'agent_123');
    expect(session.interviewerId, 'alex-lead-001');
    expect(session.interviewerName, 'Alex Rivera');
    expect(session.channel, 'fitcheck-alex-channel');
    expect(session.uid, 1001);
    expect(session.rtcToken, 'test_token');
    expect(session.appId, 'agora_app_123');
  });
}
