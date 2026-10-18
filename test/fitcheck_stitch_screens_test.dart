import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/core/theme/fitcheck_theme.dart';
import 'package:fitcheck/features/fitcheck/screens/candidate_command_center_page.dart';
import 'package:fitcheck/features/fitcheck/screens/evaluation_scorecard_page.dart';
import 'package:fitcheck/features/fitcheck/screens/fitcheck_shell.dart';
import 'package:fitcheck/features/fitcheck/screens/hardware_readiness_page.dart';
import 'package:fitcheck/features/fitcheck/screens/live_interview_studio_page.dart';
import 'package:fitcheck/features/fitcheck/screens/public_landing_page.dart';

void main() {
  group('FitCheck Stitch-First 5 Core Screens & Candidate Journey Tests', () {
    testWidgets('1. PublicLandingPage renders hero, trust badges, and triggers CTA', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool startPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: PublicLandingPage(
            onStartPreparing: () => startPressed = true,
            onSignIn: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
      expect(find.text('No credit card required'), findsOneWidget);
      expect(find.text('Realistic voice synthesis'), findsOneWidget);
      expect(find.text('48kHz audio telemetry'), findsOneWidget);
      expect(find.text('Start Preparing Free'), findsWidgets);

      await tester.tap(find.text('Start Preparing Free').first);
      expect(startPressed, isTrue);
    });

    testWidgets('2. CandidateCommandCenterPage renders telemetry stats, upcoming scenario, and action radar', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool setupPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: CandidateCommandCenterPage(
            onStartInterview: () {},
            onHardwareSetup: () => setupPressed = true,
            onViewScorecard: () {},
            onViewHistory: () {},
            onViewLibrary: () {},
            onBackToLanding: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
      expect(find.text('Simulations Completed'.toUpperCase()), findsOneWidget);
      expect(find.text('Voice Telemetry Time'.toUpperCase()), findsOneWidget);
      expect(find.text('Hire Readiness'.toUpperCase()), findsOneWidget);
      expect(find.text('Evaluated Criteria'.toUpperCase()), findsOneWidget);
      expect(find.text('High-Scale Distributed Cache with Marcus Vance (Principal Architect Persona)'), findsOneWidget);

      await tester.tap(find.text('Start Live Interview'));
      expect(setupPressed, isTrue);
    });

    testWidgets('3. HardwareReadinessPage renders 4 difficulty cards, mic check, and triggers live room', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool enterPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: HardwareReadinessPage(
            onEnterLiveRoom: () => enterPressed = true,
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Difficulty & Stress Calibration'), findsOneWidget);
      expect(find.text('Lenient'), findsOneWidget);
      expect(find.text('Realistic'), findsOneWidget);
      expect(find.text('Challenging'), findsOneWidget);
      expect(find.text('Stress / Hardcore'), findsOneWidget);
      expect(find.text('Microphone & Audio Input'), findsOneWidget);
      expect(find.text('Enter Live Interview Room'), findsOneWidget);

      await tester.tap(find.text('Enter Live Interview Room'));
      expect(enterPressed, isTrue);
    });

    testWidgets('4. LiveInterviewStudioPage renders active prompt, transcripts, controls, and concludes', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool concluded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: LiveInterviewStudioPage(
            onConcludeInterview: () => concluded = true,
            onBackToDashboard: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ACTIVE PROMPT · Q3'), findsOneWidget);
      expect(find.text('ACOUSTIC TRANSCRIPTION STREAM'), findsOneWidget);
      expect(find.text('Mute Mic'), findsOneWidget);
      expect(find.text('Conclude Simulation & Generate Evaluation'), findsOneWidget);
      expect(find.text('REAL-TIME PACING TELEMETRY'), findsOneWidget);
      expect(find.text('142 WPM'), findsOneWidget);

      await tester.tap(find.text('Conclude Simulation & Generate Evaluation'));
      expect(concluded, isTrue);
    });

    testWidgets('5. EvaluationScorecardPage renders Bento hero with score, domains, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool retake = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.darkThemeData,
          home: EvaluationScorecardPage(
            onBackToDashboard: () {},
            onRetakeSimulation: () => retake = true,
            onLaunchRecommendedDrill: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('STRONG HIRE • LEVEL 6 READY'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('Executive Scorecard'), findsOneWidget);
      expect(find.text('System Architecture & Trade-offs'), findsOneWidget);
      expect(find.text('Consensus & Fault Tolerance'), findsOneWidget);
      expect(find.text('Simulation Transcript Audit'), findsOneWidget);
      expect(find.text('Retake Simulation'), findsOneWidget);

      await tester.ensureVisible(find.text('Retake Simulation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retake Simulation'));
      expect(retake, isTrue);
    });

    testWidgets('6. Complete Candidate Flow through FitCheckShell', (tester) async {
      tester.view.physicalSize = const Size(1440, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start at Landing Page
      await tester.pumpWidget(
        const MaterialApp(
          home: FitCheckShell(initialRoute: FitCheckRoute.landing),
        ),
      );
      await tester.pump();

      // Verify Landing Page
      expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
      expect(find.text('Create someone.'), findsNothing);
      expect(find.text('Your Characters'), findsNothing);

      // Tap "Start Preparing Free" on Landing Page -> navigate to Auth
      await tester.tap(find.text('Start Preparing Free').first);
      await tester.pump();
      expect(find.text('AI Real-Time Interview Simulation & Screening'), findsOneWidget);

      // Authenticate via Demo Candidate -> navigate to Command Center
      await tester.tap(find.byKey(const Key('demo_candidate_sign_in_button')));
      await tester.pump();
      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
      expect(find.text('Create Character'), findsNothing);

      // Tap "Start Live Interview" on Command Center -> navigate to Hardware Setup
      await tester.tap(find.text('Start Live Interview'));
      await tester.pump();
      expect(find.text('Difficulty & Stress Calibration'), findsOneWidget);

      // Tap "Enter Live Interview Room" on Hardware Setup -> navigate to Live Room
      await tester.tap(find.text('Enter Live Interview Room'));
      await tester.pump();
      expect(find.text('Marcus Vance'), findsWidgets);
      expect(find.text('End Interview'), findsOneWidget);

      // Tap "End Interview" -> confirmation dialog -> tap "End & Evaluate" -> navigate to Evaluation Scorecard
      await tester.tap(find.text('End Interview'));
      await tester.pump();
      expect(find.text('End & Evaluate'), findsOneWidget);
      await tester.tap(find.text('End & Evaluate'));
      await tester.pump();
      expect(find.text('STRONG HIRE • LEVEL 6 READY'), findsOneWidget);

      // Tap "Return to Command Center" -> back to Command Center
      await tester.ensureVisible(find.text('Return to Command Center'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Return to Command Center'));
      await tester.pump();
      expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);

      // Tap "Sign Out" in sidebar -> returns to Public Landing Page
      await tester.tap(find.byKey(const Key('sidebar_sign_out_button')));
      await tester.pump();
      expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
      expect(find.text('Create someone.'), findsNothing);
    });
  });
}
