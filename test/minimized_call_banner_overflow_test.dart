import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitcheck/features/call/call_session_manager.dart';
import 'package:fitcheck/features/call/minimized_call_banner.dart';
import 'package:fitcheck/features/fitcheck/fitcheck_api_service.dart';

void main() {
  testWidgets('MinimizedCallBanner renders without overflow on narrow screens with long name and duration', (tester) async {
    const longNameInterviewer = FitCheckInterviewer(
      id: 'int-long',
      name: 'Dr. Alexander Montgomery III, Senior Systems Architect',
      title: 'Chief of Planetary Biology and Distributed Systems Exploration',
      questioningStyle: 'challenging',
      voiceId: 'Aoede',
    );

    final manager = CallSessionManager.instance;
    manager.resetForTesting();
    manager.setStateForTesting(
      interviewer: longNameInterviewer,
      status: CallStatus.minimized,
      seconds: 3665, // 1:01:05
    );

    // Test on very narrow device width (320px)
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => Stack(
                  children: [
                    ?child,
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: MinimizedCallBanner(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        home: const Scaffold(body: Center(child: Text('Home Page'))),
      ),
    );

    await tester.pump();

    // Verify banner is rendered
    expect(find.byType(MinimizedCallBanner), findsOneWidget);
    expect(find.textContaining('Dr. Alexander Montgomery III'), findsOneWidget);
    expect(find.textContaining('Interview in progress'), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsOneWidget);

    // Verify no RenderFlex overflow exception
    expect(tester.takeException(), isNull);
  });
}
