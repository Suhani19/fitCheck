import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/auth/auth_service.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';
import 'package:fitcheck/features/fitcheck/screens/candidate_command_center_page.dart';
import 'package:fitcheck/features/fitcheck/screens/evaluation_scorecard_page.dart';
import 'package:fitcheck/features/fitcheck/screens/fitcheck_shell.dart';

void main() {
  group('FitCheck Candidate Identity, Persistence & Safe Decoupling Tests', () {
    testWidgets('CandidateCommandCenterPage displays real candidate identity, headline, and skills', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const candidate = FitCheckCandidate(
        id: 'cand-real-42',
        fullName: 'Jane Doe',
        headline: 'Senior Distributed Systems Architect',
        skills: ['Raft', 'Kubernetes', 'Go'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            candidate: candidate,
            currentUser: const FitCheckUser(uid: 'u-42', email: 'jane@arch.io', displayName: 'Jane Doe'),
            onStartInterview: () {},
            onHardwareSetup: () {},
            onViewScorecard: () {},
            onViewHistory: () {},
            onViewLibrary: () {},
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
      expect(find.text('Welcome back, Jane Doe. Ready for your simulation?'), findsOneWidget);
      expect(find.text('Raft'), findsOneWidget);
      expect(find.text('Kubernetes'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);
      expect(find.byKey(const Key('edit_candidate_profile_button')), findsOneWidget);
    });

    testWidgets('CandidateCommandCenterPage shows honest empty state when candidate has 0 sessions', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const candidate = FitCheckCandidate(
        id: 'cand-new-1',
        fullName: 'Alex Rivera',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            candidate: candidate,
            sessions: const [],
            evaluations: const [],
            isDemoMode: false,
            onStartInterview: () {},
            onHardwareSetup: () {},
            onViewScorecard: () {},
            onViewHistory: () {},
            onViewLibrary: () {},
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AWAITING FIRST SIMULATION'), findsOneWidget);
      expect(find.text('Ready to benchmark your technical readiness?'), findsOneWidget);
      expect(find.text('Configure & Start First Simulation'), findsOneWidget);
      expect(find.text('No past sessions recorded'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('0.0 hrs'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('CandidateCommandCenterPage shows explicit DEMO MODE badge when in demo mode', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            isDemoMode: true,
            onStartInterview: () {},
            onHardwareSetup: () {},
            onViewScorecard: () {},
            onViewHistory: () {},
            onViewLibrary: () {},
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
      expect(find.text('DEMO MODE • SAMPLE DATA'), findsOneWidget);
      expect(find.text('Good evening, Elena. Ready for your Stripe simulation?'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('9.4 hrs'), findsOneWidget);
    });

    testWidgets('CandidateCommandCenterPage profile dialog opens and triggers onProfileUpdated', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      FitCheckCandidate? updatedCandidate;

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            candidate: const FitCheckCandidate(id: 'c-1', fullName: 'John Initial'),
            onProfileUpdated: (updated) => updatedCandidate = updated,
            onStartInterview: () {},
            onHardwareSetup: () {},
            onViewScorecard: () {},
            onViewHistory: () {},
            onViewLibrary: () {},
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('edit_candidate_profile_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Edit Candidate Profile'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('candidate_edit_name_field')), 'John Updated');
      await tester.enterText(find.byKey(const Key('candidate_edit_headline_field')), 'Staff SRE');
      await tester.enterText(find.byKey(const Key('candidate_edit_skills_field')), 'Linux, C++, eBPF');

      await tester.tap(find.byKey(const Key('candidate_save_profile_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(updatedCandidate, isNotNull);
      expect(updatedCandidate!.fullName, 'John Updated');
      expect(updatedCandidate!.headline, 'Staff SRE');
      expect(updatedCandidate!.skills, contains('eBPF'));
    });

    testWidgets('EvaluationScorecardPage renders real evaluation overall score, recommendation, and competencies', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const evaluation = FitCheckEvaluation(
        id: 'eval-live-99',
        sessionId: 'sess-live-88',
        overallScore: 4.6, // 4.6 * 20 = 92/100
        overallRecommendation: 'Strong Hire • Staff Calibration',
        summaryVerdict: 'Candidate articulated exceptional consensus recovery and partitioning strategies.',
        competencyScores: [
          {'name': 'Distributed Consensus', 'score': 4.8, 'reasoning': 'Flawless Multi-Raft quorum analysis.'},
          {'name': 'System Architecture', 'score': 4.4, 'reasoning': 'Sound multi-region trade-offs.'},
        ],
        preparationRecommendations: ['Review cross-AZ replication lag bounds.'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: EvaluationScorecardPage(
            evaluation: evaluation,
            onBackToDashboard: () {},
            onRetakeSimulation: () {},
            onLaunchRecommendedDrill: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('STRONG HIRE • STAFF CALIBRATION'), findsOneWidget);
      expect(find.text('92'), findsOneWidget);
      expect(find.text('Candidate articulated exceptional consensus recovery and partitioning strategies.'), findsOneWidget);
      expect(find.text('Distributed Consensus'), findsOneWidget);
      expect(find.text('System Architecture'), findsOneWidget);
      expect(find.text('Review cross-AZ replication lag bounds.'), findsOneWidget);
    });

    testWidgets('FitCheckShell boots directly into FitCheck without any legacy screens', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: FitCheckShell(),
        ),
      );
      await tester.pump();

      expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
      expect(find.text('Start Preparing Free'), findsWidgets);
      expect(find.text('Create a Companion'), findsNothing);
      expect(find.text('Your Characters'), findsNothing);
      expect(find.text('Create someone. Bring them to life.'), findsNothing);
    });
  });
}
