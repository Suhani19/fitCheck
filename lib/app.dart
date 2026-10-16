import 'package:flutter/material.dart';
import 'core/auth/auth_service.dart';
import 'core/theme/fitcheck_theme.dart';
import 'features/call/minimized_call_banner.dart';
import 'features/fitcheck/fitcheck_api_service.dart';
import 'features/fitcheck/screens/fitcheck_shell.dart';

class FitCheckApp extends StatelessWidget {
  final Widget? home;
  final bool? initialOnboardingCompleted;
  final AuthService? authService;
  final FitCheckApiService? apiService;

  const FitCheckApp({
    super.key,
    this.home,
    this.initialOnboardingCompleted,
    this.authService,
    this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    final Widget effectiveHome =
        home ??
        FitCheckShell(
          authService: authService,
          apiService: apiService,
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitCheck',
      theme: FitCheckTheme.darkThemeData,
      darkTheme: FitCheckTheme.darkThemeData,
      themeMode: ThemeMode.dark,
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
      home: effectiveHome,
    );
  }
}
