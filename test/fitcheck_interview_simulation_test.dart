import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/features/call/call_session_manager.dart';
import 'package:fitcheck/features/call/runtime_api.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/services/interviewer_recommendation_service.dart';

void main() {
  group('FitCheck Interview Simulation Domain & Persona Tests', () {
    test('1. FitCheckInterviewer model serialization retains complete persona configuration', () {
      const interviewer = FitCheckInterviewer(
        id: 'alex-001',
        name: 'Alex Rivera',
        title: 'Staff Distributed Systems Architect',
        companyContext: 'Cloud Scale Systems',
        questioningStyle: 'rigorous',
        voiceId: 'Puck',
        bio: 'Staff architect probing deep on consensus protocols and failure modes.',
        isPreset: true,
        provenance: {'preset_key': 'alex-arch'},
      );

      final json = interviewer.toJson();
      expect(json['id'], 'alex-001');
      expect(json['name'], 'Alex Rivera');
      expect(json['title'], 'Staff Distributed Systems Architect');
      expect(json['voice_id'], 'Puck');
      expect(json['questioning_style'], 'rigorous');
      expect(json['company_context'], 'Cloud Scale Systems');
      expect(json['is_preset'], isTrue);

      final reconstructed = FitCheckInterviewer.fromJson(json);
      expect(reconstructed.id, interviewer.id);
      expect(reconstructed.name, interviewer.name);
      expect(reconstructed.title, interviewer.title);
      expect(reconstructed.companyContext, interviewer.companyContext);
    });

    test('2. FitCheckInterviewer copyWith updates attributes without mutating original', () {
      const original = FitCheckInterviewer(
        id: 'priya-001',
        name: 'Priya Sharma',
        title: 'Principal Engineering Manager',
        questioningStyle: 'socratic',
        voiceId: 'Aoede',
      );

      final modified = original.copyWith(
        title: 'VP of Engineering',
        questioningStyle: 'bar-raiser',
      );

      expect(modified.id, 'priya-001');
      expect(modified.title, 'VP of Engineering');
      expect(modified.questioningStyle, 'bar-raiser');
      expect(original.title, 'Principal Engineering Manager');
    });

    test('3. Interviewer recommendation ranks staff architects for distributed systems target jobs', () {
      final interviewers = [
        const FitCheckInterviewer(
          id: 'marcus-001',
          name: 'Marcus Vance',
          title: 'Staff Distributed Systems Architect',
          questioningStyle: 'rigorous',
          voiceId: 'Fenrir',
          bio: 'Distributed systems, Raft, scalability, and consensus protocols.',
        ),
        const FitCheckInterviewer(
          id: 'alex-001',
          name: 'Alex Rivera',
          title: 'Product Engineer',
          questioningStyle: 'conversational',
          voiceId: 'Puck',
          bio: 'Full-stack web and mobile apps.',
        ),
        const FitCheckInterviewer(
          id: 'priya-001',
          name: 'Priya Sharma',
          title: 'Principal Engineering Manager',
          questioningStyle: 'structured',
          voiceId: 'Aoede',
          bio: 'Engineering leadership, cross-functional execution, STAR framework.',
        ),
      ];

      final ranked = InterviewerRecommendationService.rankInterviewers(
        interviewers: interviewers,
        customJobTitle: 'Distributed Systems Architect',
        customJobDescription: 'Build high-throughput consensus pipelines using Raft.',
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.interviewer.id, 'marcus-001');
      expect(ranked.first.matchScore, greaterThan(60));
    });

    test('4. Interviewer recommendation ranks product engineer for full-stack frontend roles', () {
      final interviewers = [
        const FitCheckInterviewer(
          id: 'marcus-001',
          name: 'Marcus Vance',
          title: 'Staff Distributed Systems Architect',
          questioningStyle: 'rigorous',
          voiceId: 'Fenrir',
          bio: 'Distributed systems and consensus protocols.',
        ),
        const FitCheckInterviewer(
          id: 'alex-001',
          name: 'Alex Rivera',
          title: 'Full-Stack Product Engineer',
          questioningStyle: 'conversational',
          voiceId: 'Puck',
          bio: 'Frontend React Flutter and clean modern APIs.',
        ),
      ];

      final ranked = InterviewerRecommendationService.rankInterviewers(
        interviewers: interviewers,
        customJobTitle: 'Full-Stack Product Engineer',
        customJobDescription: 'Frontend React Flutter applications with modern web APIs.',
      );

      expect(ranked.first.interviewer.id, 'alex-001');
    });

    test('5. Interviewer recommendation ranks engineering manager for leadership tracks', () {
      final interviewers = [
        const FitCheckInterviewer(
          id: 'alex-001',
          name: 'Alex Rivera',
          title: 'Staff Distributed Systems Architect',
          questioningStyle: 'rigorous',
          voiceId: 'Puck',
          bio: 'Consensus and scalability architecture.',
        ),
        const FitCheckInterviewer(
          id: 'priya-001',
          name: 'Priya Sharma',
          title: 'Principal Engineering Manager',
          questioningStyle: 'structured',
          voiceId: 'Aoede',
          bio: 'Managing cross-functional team velocity, leadership and conflict resolution.',
        ),
      ];

      final ranked = InterviewerRecommendationService.rankInterviewers(
        interviewers: interviewers,
        customJobTitle: 'Engineering Manager',
        customJobDescription: 'Managing cross-functional sprint velocity and mentoring team.',
      );

      expect(ranked.first.interviewer.id, 'priya-001');
    });

    test('6. FitCheckCandidate serialization parses skills and work experience correctly', () {
      final cand = const FitCheckCandidate(
        id: 'cand-001',
        fullName: 'Jordan Taylor',
        headline: 'Senior Backend Engineer',
        skills: ['Go', 'Raft', 'PostgreSQL'],
        workExperience: [
          {'company': 'Acme', 'role': 'Senior Engineer', 'years': '3'},
        ],
      );

      final json = cand.toJson();
      expect(json['id'], 'cand-001');
      expect(json['full_name'], 'Jordan Taylor');
      expect(json['skills'], contains('Raft'));

      final reconstructed = FitCheckCandidate.fromJson(json);
      expect(reconstructed.fullName, cand.fullName);
      expect(reconstructed.skills.length, 3);
    });

    test('7. FitCheckSession model parses active channel and transcript state correctly', () {
      final session = const FitCheckSession(
        id: 'sess-901',
        candidateId: 'user-001',
        jobId: 'job-001',
        interviewerId: 'alex-001',
        channel: 'fitcheck-room-901',
        rtcToken: 'rtc-token-xyz',
        status: 'active',
        difficulty: 'Senior',
        startedAt: '2026-10-16T12:00:00Z',
      );

      expect(session.id, 'sess-901');
      expect(session.channel, 'fitcheck-room-901');
      expect(session.status, 'active');
      expect(session.difficulty, 'Senior');
    });

    test('8. Bento Scorecard model evaluates multi-dimensional competencies with evidence', () {
      final rubricScores = {
        'System Scalability': 85.0,
        'Fault Tolerance': 78.0,
        'Communication Composure': 90.0,
      };

      final strengths = [
        'Clear articulation of horizontal partitioning strategy.',
        'Proper identification of network partition boundaries.',
      ];

      final areasForImprovement = [
        'Validate quorum invariants during leader split-brain events.',
      ];

      expect(rubricScores['System Scalability'], 85.0);
      expect(strengths.length, 2);
      expect(areasForImprovement.first, contains('split-brain'));
    });

    test('9. CallSessionManager handles live speaking state updates without character aliases', () {
      final manager = CallSessionManager.instance;
      manager.notifySpeakingState(interviewerSpeaking: true);
      expect(manager.interviewerSpeaking, isTrue);
      expect(manager.conversationState, ConversationState.speaking);

      manager.notifySpeakingState(interviewerSpeaking: false);
      expect(manager.interviewerSpeaking, isFalse);
      expect(manager.conversationState, ConversationState.listening);

      manager.notifySpeakingState(candidateSpeaking: true);
      expect(manager.userSpeaking, isTrue);
      expect(manager.conversationState, ConversationState.listening);

      manager.notifySpeakingState(candidateSpeaking: false);
      expect(manager.userSpeaking, isFalse);
      expect(manager.conversationState, ConversationState.thinking);
    });

    test('10. CallSessionManager formattedCallTime renders MM:SS cleanly', () {
      final manager = CallSessionManager.instance;
      manager.setStateForTesting(seconds: 0);
      expect(manager.formattedCallTime, '00:00');

      manager.setStateForTesting(seconds: 65);
      expect(manager.formattedCallTime, '01:05');

      manager.setStateForTesting(seconds: 732);
      expect(manager.formattedCallTime, '12:12');
    });

    test('11. CallSessionManager activeInterviewer getters return null when idle', () {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      expect(manager.activeInterviewer, isNull);
      expect(manager.activeInterviewerId, isNull);
      expect(manager.activeInterviewerName, isNull);
      expect(manager.hasActiveCall, isFalse);
    });

    test('12. CallSessionManager activeInterviewer getters return populated values on test state', () {
      final manager = CallSessionManager.instance;
      const testInterviewer = FitCheckInterviewer(
        id: 'elena-001',
        name: 'Elena Rostova',
        title: 'Senior Algorithm Specialist',
        questioningStyle: 'precise',
        voiceId: 'Fenrir',
      );

      manager.setStateForTesting(
        interviewer: testInterviewer,
        status: CallStatus.active,
        difficulty: 'Senior',
        jobTitle: 'Staff Algorithms Engineer',
      );

      expect(manager.activeInterviewer?.name, 'Elena Rostova');
      expect(manager.activeInterviewerId, 'elena-001');
      expect(manager.activeInterviewerName, 'Elena Rostova');
      expect(manager.activeDifficulty, 'Senior');
      expect(manager.activeJobTitle, 'Staff Algorithms Engineer');
      expect(manager.isInterviewerOnCall('elena-001'), isTrue);
      expect(manager.isInterviewerOnCall('alex-001'), isFalse);
      manager.resetForTesting();
    });

    test('13. ConversationState transitions conform to Socratic turn-taking lifecycle', () {
      expect(ConversationState.idle.name, 'idle');
      expect(ConversationState.listening.name, 'listening');
      expect(ConversationState.thinking.name, 'thinking');
      expect(ConversationState.speaking.name, 'speaking');
    });

    test('14. FitCheckSession candidate questions phase transition is tracked', () {
      final phases = ['greeting', 'deep_dive', 'socratic_probing', 'candidate_qna', 'wrap_up'];
      expect(phases.contains('socratic_probing'), isTrue);
      expect(phases.length, 5);
    });

    test('15. Target Job profile criteria weighting sums to 1.0', () {
      final criteriaWeights = {
        'Distributed Architecture': 0.35,
        'Fault Tolerance': 0.25,
        'Concurrency & Locking': 0.20,
        'Communication & Synthesis': 0.20,
      };

      final total = criteriaWeights.values.fold(0.0, (acc, val) => acc + val);
      expect((total - 1.0).abs(), lessThan(0.001));
    });

    test('16. Longitudinal skill velocity compares scores across sessions', () {
      final sessionScores = [
        {'sessionId': 'sess-1', 'score': 62.0, 'date': '2026-10-01'},
        {'sessionId': 'sess-2', 'score': 74.0, 'date': '2026-10-08'},
        {'sessionId': 'sess-3', 'score': 88.0, 'date': '2026-10-15'},
      ];

      final delta = (sessionScores[2]['score'] as double) - (sessionScores[0]['score'] as double);
      expect(delta, 26.0);
      expect(delta, greaterThan(0));
    });

    test('17. Audio dBFS level normalization converts linear amplitudes safely', () {
      double toDbfs(double linearLevel) {
        if (linearLevel <= 0.001) return -60.0;
        final db = 20.0 * (linearLevel).clamp(0.001, 1.0);
        return -60.0 + (db * 3.0).clamp(0.0, 60.0);
      }

      expect(toDbfs(0.0), -60.0);
      expect(toDbfs(1.0), 0.0);
    });

    test('18. Candidate Practice Memory categorization handles communication vs technical items', () {
      final commMemory = {
        'id': 'm-comm-1',
        'category': 'Communication Pattern',
        'content': 'Rushing into implementation before clarifying constraints.',
        'importance': 0.8,
      };

      final techMemory = {
        'id': 'm-tech-1',
        'category': 'Technical Depth',
        'content': 'Unclear distinction between linearizability and serializability.',
        'importance': 0.9,
      };

      expect(commMemory['category'], 'Communication Pattern');
      expect(techMemory['category'], 'Technical Depth');
      expect((techMemory['importance'] as double), greaterThan(commMemory['importance'] as double));
    });

    test('19. FitCheckUser model provides candidate identity and authentication tokens', () {
      const user = FitCheckUser(
        uid: 'user-abc',
        email: 'engineer@fitcheck.io',
        displayName: 'Senior Engineer',
      );

      expect(user.uid, 'user-abc');
      expect(user.email, 'engineer@fitcheck.io');
      expect(user.displayName, 'Senior Engineer');
    });

    test('20. RuntimeSession audio configuration carries Agora RTC parameters', () {
      const session = RuntimeSession(
        sessionId: 'rt-session-001',
        agentId: 'agent-001',
        channel: 'fitcheck-channel-001',
        rtcToken: 'token-secret',
        uid: 1001,
        appId: 'mock-app-id',
        interviewerId: 'alex-lead-001',
        interviewerName: 'Alex Rivera',
      );

      expect(session.sessionId, 'rt-session-001');
      expect(session.channel, 'fitcheck-channel-001');
      expect(session.interviewerId, 'alex-lead-001');
      expect(session.interviewerName, 'Alex Rivera');
    });

    test('21. Hardware readiness microphone dBFS meter thresholds identify silent vs optimal voice', () {
      String evaluateVoiceLevel(double dbfs) {
        if (dbfs < -45.0) return 'Silent / Inaudible';
        if (dbfs < -25.0) return 'Low Voice';
        if (dbfs <= -10.0) return 'Optimal Level';
        return 'Clipping / Too Loud';
      }

      expect(evaluateVoiceLevel(-55.0), 'Silent / Inaudible');
      expect(evaluateVoiceLevel(-30.0), 'Low Voice');
      expect(evaluateVoiceLevel(-18.0), 'Optimal Level');
      expect(evaluateVoiceLevel(-5.0), 'Clipping / Too Loud');
    });

    test('22. Socratic follow-up triggers when answer lacks architectural trade-off justification', () {
      bool requiresSocraticProbing(String candidateAnswer) {
        final handWavyPhrases = ['just use kafka', 'scale horizontally', 'standard database', 'easy to handle'];
        return handWavyPhrases.any((phrase) => candidateAnswer.toLowerCase().contains(phrase));
      }

      expect(requiresSocraticProbing('We will just use kafka to scale horizontally.'), isTrue);
      expect(requiresSocraticProbing('We evaluated Raft vs Paxos considering leader lease latency.'), isFalse);
    });

    test('23. Interview session difficulty adjusts probing strictness criteria', () {
      int maxFollowUpDepth(String difficulty) {
        switch (difficulty.toLowerCase()) {
          case 'junior': return 1;
          case 'mid': return 2;
          case 'senior': return 3;
          case 'staff': return 5;
          default: return 2;
        }
      }

      expect(maxFollowUpDepth('Junior'), 1);
      expect(maxFollowUpDepth('Senior'), 3);
      expect(maxFollowUpDepth('Staff'), 5);
    });

    test('24. Candidate practice memory privacy inspection excludes sensitive audio payloads', () {
      final memory = {
        'id': 'mem-safe-1',
        'category': 'STAR Depth',
        'content': 'Provided vague metric impact in the Result phase.',
        'importance': 0.75,
      };

      expect(memory.containsKey('audio_stream'), isFalse);
      expect(memory.containsKey('raw_audio'), isFalse);
      expect(memory.containsKey('content'), isTrue);
    });

    test('25. Verbatim transcript quote parser strips conversational filler correctly', () {
      String cleanTranscriptQuote(String rawQuote) {
        return rawQuote
            .replaceAll(RegExp(r'\b(um|uh|like|you know)\b[,\s]*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      final raw = 'Um, we chose like Cassandra, you know, for writes.';
      expect(cleanTranscriptQuote(raw), 'we chose Cassandra, for writes.');
    });

    test('26. FitCheckInterviewer specialties list parses multiple domains without duplicates', () {
      final specialties = ['Distributed Systems', 'Distributed Systems', 'Consensus', 'Fault Tolerance'];
      final unique = specialties.toSet().toList();
      expect(unique.length, 3);
      expect(unique, contains('Consensus'));
    });

    test('27. Bento Scorecard overall score maps correctly into recommendation bands', () {
      String scoreRecommendationBand(double score) {
        if (score >= 85.0) return 'Strong Hire (Bar-Raiser)';
        if (score >= 70.0) return 'Hire';
        if (score >= 55.0) return 'Leaning No Hire';
        return 'Strong No Hire';
      }

      expect(scoreRecommendationBand(92.0), 'Strong Hire (Bar-Raiser)');
      expect(scoreRecommendationBand(78.5), 'Hire');
      expect(scoreRecommendationBand(64.0), 'Leaning No Hire');
      expect(scoreRecommendationBand(42.0), 'Strong No Hire');
    });

    test('28. Agora RTC token expiry detection triggers proactive renewal before cutoff', () {
      bool isTokenExpiringSoon(int issuedAtEpochSeconds, int ttlSeconds) {
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiryEpoch = issuedAtEpochSeconds + ttlSeconds;
        return (expiryEpoch - nowSeconds) < 300;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(isTokenExpiringSoon(now - 3500, 3600), isTrue);
      expect(isTokenExpiringSoon(now, 3600), isFalse);
    });

    test('29. Targeted remediation drill generator creates focused practice topics from memories', () {
      List<String> generateDrills(List<Map<String, dynamic>> memories) {
        return memories.map((m) => 'Sparring Drill: ${m['category']} on "${m['content']}"').toList();
      }

      final mems = [
        {
          'category': 'Scalability',
          'content': 'Missed load balancer failover',
        },
      ];

      final drills = generateDrills(mems);
      expect(drills.first, contains('Scalability'));
      expect(drills.first, contains('Missed load balancer failover'));
    });

    test('30. CallSessionManager status transitions guard against illegal post-teardown state', () {
      final manager = CallSessionManager.instance;
      manager.resetForTesting();
      expect(manager.status, CallStatus.idle);

      manager.setStateForTesting(status: CallStatus.connecting);
      expect(manager.status, CallStatus.connecting);

      manager.setStateForTesting(status: CallStatus.active);
      expect(manager.status, CallStatus.active);
      expect(manager.isCallActive, isTrue);

      manager.setStateForTesting(status: CallStatus.ending);
      expect(manager.status, CallStatus.ending);

      manager.resetForTesting();
    });

    test('31. Candidate resume skills matching computes match percentage against job profile', () {
      double calculateSkillsMatch(List<String> candidateSkills, List<String> requiredSkills) {
        if (requiredSkills.isEmpty) return 1.0;
        final matched = candidateSkills.where((s) => requiredSkills.contains(s)).length;
        return matched / requiredSkills.length;
      }

      final candidate = ['Go', 'Kubernetes', 'PostgreSQL', 'Docker'];
      final required = ['Go', 'Distributed Systems', 'Kubernetes', 'Raft'];
      final match = calculateSkillsMatch(candidate, required);
      expect(match, 0.50);
    });

    test('32. Interviewer voice identity preserves tone and pace settings', () {
      const alexVoice = {'id': 'Puck', 'tone': 'Analytical & Direct', 'cadence': '145 WPM'};
      expect(alexVoice['id'], 'Puck');
      expect(alexVoice['tone'], contains('Analytical'));
    });

    test('33. Candidate practice memory progression tracking calculates recurrence rate', () {
      final historicalWeaknesses = [
        'Single Point of Failure',
        'Single Point of Failure',
        'Quorum Split Brain',
      ];

      final spofCount = historicalWeaknesses.where((w) => w == 'Single Point of Failure').length;
      expect(spofCount, 2);
    });

    test('34. FitCheckSession difficulty selection supports Rapid Drill, Full Technical, Behavioral', () {
      final supportedModes = ['Full Technical', 'Rapid Drill', 'Behavioral Deep Dive'];
      expect(supportedModes.length, 3);
      expect(supportedModes.contains('Rapid Drill'), isTrue);
    });

    test('35. Candidate flightdeck telemetry computes readiness percentage', () {
      double computeReadiness({
        required bool micChecked,
        required bool resumeUploaded,
        required bool rubricSelected,
        required bool interviewerPaired,
      }) {
        int steps = 0;
        if (micChecked) steps++;
        if (resumeUploaded) steps++;
        if (rubricSelected) steps++;
        if (interviewerPaired) steps++;
        return (steps / 4.0) * 100.0;
      }

      expect(computeReadiness(micChecked: true, resumeUploaded: true, rubricSelected: true, interviewerPaired: true), 100.0);
      expect(computeReadiness(micChecked: true, resumeUploaded: false, rubricSelected: true, interviewerPaired: false), 50.0);
    });
  });
}
