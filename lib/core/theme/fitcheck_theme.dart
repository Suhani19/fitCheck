import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Precision Studio Design System for FitCheck.
/// Direct implementation of Stitch design tokens and theme specs.
class FitCheckTheme {
  FitCheckTheme._();

  /// Initialize theme and prevent GoogleFonts runtime fetching during automated testing.
  static void init() {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      GoogleFonts.config.allowRuntimeFetching = false;
    }
  }

  // Surface Hierarchy
  static const Color surfaceCanvas = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF101419);
  static const Color surfaceDim = Color(0xFF101419);
  static const Color surfaceBright = Color(0xFF36393F);
  static const Color surfaceContainerLowest = Color(0xFF0A0E13);
  static const Color surfaceContainerLow = Color(0xFF181C21);
  static const Color surfaceContainer = Color(0xFF1C2025);
  static const Color surfaceContainerHigh = Color(0xFF262A30);
  static const Color surfaceContainerHighest = Color(0xFF31353B);

  // Accents & Telemetry
  static const Color primary = Color(0xFF5CE2F6); // Studio Cyan
  static const Color primaryContainer = Color(0xFF35C6D9);
  static const Color onPrimary = Color(0xFF00363D);
  static const Color onPrimaryContainer = Color(0xFF004E57);

  static const Color secondary = Color(0xFFCEBDFF); // Studio Lavender
  static const Color secondaryContainer = Color(0xFF4F319C);
  static const Color onSecondary = Color(0xFF381385);
  static const Color onSecondaryContainer = Color(0xFFBEA8FF);

  static const Color tertiary = Color(0xFF5AE9AC); // Muted Emerald
  static const Color tertiaryContainer = Color(0xFF36CC92);
  static const Color onTertiary = Color(0xFF003824);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFFFB4AB); // Studio Coral
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);

  // Neutrals & Structure
  static const Color onSurface = Color(0xFFE0E2EA);
  static const Color onSurfaceVariant = Color(0xFFBBC9CB);
  static const Color outline = Color(0xFF869395);
  static const Color outlineVariant = Color(0xFF3C494B);

  // Backwards Compatibility Aliases
  static const Color background = surface;
  static const Color surfaceElevated = surfaceContainerHigh;
  static const Color border = outlineVariant;
  static const Color borderSubtle = Color(0xFF223046);
  static const Color primaryGlow = primaryContainer;
  static const Color success = tertiary;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textMuted = outline;

  // Canonical Spacing System (docs/designs/DESIGN_SYSTEM.md)
  static const double spaceXXS = 2.0;
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 12.0;
  static const double spaceLG = 16.0;
  static const double spaceXL = 24.0;
  static const double space2XL = 32.0;
  static const double space3XL = 48.0;

  // Canonical Border Radius System
  static const double radiusXS = 2.0;
  static const double radiusSM = 4.0; // standard buttons & inputs
  static const double radiusMD = 8.0; // standard cards & panels
  static const double radiusLG = 12.0;
  static const double radiusXL = 16.0;
  static const double radius2XL = 24.0;
  static const double radiusFull = 999.0;

  // Canonical Studio Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient studioCardGlow = LinearGradient(
    colors: [Color(0x225CE2F6), Color(0x18CEBDFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient equalizerGradient = LinearGradient(
    colors: [primaryContainer, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient telemetryBarGradient = LinearGradient(
    colors: [primary, tertiary],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );

  // Difficulty Badges
  static Color difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'lenient':
        return tertiary;
      case 'realistic':
        return primary;
      case 'challenging':
        return warning;
      case 'expert_stress':
      case 'stress':
        return const Color(0xFFEF4444);
      default:
        return textSecondary;
    }
  }

  // Typography Tokens
  static TextStyle displayLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 40,
        height: 48 / 40,
        letterSpacing: -0.8,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle headlineXLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.64,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle headlineLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 24,
        height: 32 / 24,
        letterSpacing: -0.36,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle headlineMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 20,
        height: 28 / 20,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w500,
        color: color ?? onSurface,
      );

  static TextStyle titleMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        letterSpacing: -0.1,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        letterSpacing: -0.08,
        fontWeight: FontWeight.w400,
        color: color ?? onSurface,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: color ?? onSurface,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        height: 18 / 13,
        letterSpacing: 0,
        fontWeight: FontWeight.w400,
        color: color ?? onSurfaceVariant,
      );

  static TextStyle metricDisplay({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        height: 32 / 28,
        letterSpacing: -0.56,
        fontWeight: FontWeight.w600,
        color: color ?? onSurface,
      );

  static TextStyle labelMedium({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.24,
        fontWeight: FontWeight.w500,
        color: color ?? onSurfaceVariant,
      );

  static TextStyle labelSmall({Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        height: 14 / 11,
        letterSpacing: 0.44,
        fontWeight: FontWeight.w500,
        color: color ?? outline,
      );

  // Full Flutter ThemeData
  static ThemeData get darkThemeData {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiary,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: error,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainerLow,
        foregroundColor: onSurface,
        elevation: 0,
        titleTextStyle: headlineMedium(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
