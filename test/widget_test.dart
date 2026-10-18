import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/app.dart';

void main() {
  testWidgets('FitCheck App startup: unauthenticated lands on Public Landing, signs in to Command Center', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Fresh application launch
    await tester.pumpWidget(const FitCheckApp());
    await tester.pump();

    // 2. Unauthenticated user sees FitCheck Public Landing Experience
    expect(find.text('FitCheck'), findsWidgets);
    expect(find.text("Your next interview shouldn't be a surprise."), findsOneWidget);
    expect(find.text('No credit card required'), findsOneWidget);
    expect(find.text('Realistic voice synthesis'), findsOneWidget);
    expect(find.text('Start Preparing Free'), findsWidgets);

    // 3. Candidate taps "Sign In" / "Start Preparing Free" -> navigates to FitCheck Auth
    await tester.tap(find.text('Start Preparing Free').first);
    await tester.pump();

    expect(find.text('AI Real-Time Interview Simulation & Screening'), findsOneWidget);
    expect(find.byKey(const Key('demo_candidate_sign_in_button')), findsOneWidget);

    // 4. Authenticate as candidate -> enters Candidate Command Center flightdeck
    await tester.tap(find.byKey(const Key('demo_candidate_sign_in_button')));
    await tester.pump();

    expect(find.text('Candidate Command Center'), findsOneWidget);
    expect(find.text('INTERVIEW READINESS DASHBOARD'), findsOneWidget);
    expect(find.text('Start Live Interview'), findsOneWidget);
  });
}
