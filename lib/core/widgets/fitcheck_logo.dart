import 'package:flutter/material.dart';
import '../theme/fitcheck_theme.dart';

/// Official FitCheck Logo component supporting dark and light backgrounds.
///
/// Note on assets:
/// - `assets/images/fitcheck_logo_light.png`: Pure black background with radiant silver/platinum
///   ribbon mark. Ideal for DARK themes and dark surfaces (e.g. `#09090B`, `#101419`).
/// - `assets/images/fitcheck_logo_dark.png`: Pure white background with dark graphite ribbon mark.
///   Ideal for LIGHT themes and light surfaces (e.g. `#FFFFFF`, light cards).
class FitCheckLogo extends StatelessWidget {
  /// Dimension (width and height) of the logo symbol mark.
  final double size;

  /// Whether the logo is placed on a dark surface (defaults to `true` for Precision Studio dark theme).
  final bool? isDarkBackground;

  /// Whether to render the 'FitCheck' wordmark next to the symbol.
  final bool showWordmark;

  /// Custom font size for the wordmark text.
  final double? wordmarkSize;

  /// Whether to render the 'GET FIT. CHECK FIT.' subtitle below the wordmark.
  final bool showTagline;

  /// Border radius applied to the logo emblem.
  final BorderRadius? borderRadius;

  /// Optional custom border for the logo emblem.
  final BoxBorder? border;

  /// Optional callback when tapping the logo (e.g. navigate home).
  final VoidCallback? onTap;

  const FitCheckLogo({
    super.key,
    this.size = 28,
    this.isDarkBackground,
    this.showWordmark = false,
    this.wordmarkSize,
    this.showTagline = false,
    this.borderRadius,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // If isDarkBackground not explicitly specified, detect from Theme brightness
    final bool dark = isDarkBackground ?? (Theme.of(context).brightness == Brightness.dark);
    final String assetPath = dark
        ? 'assets/images/fitcheck_logo_light.png'
        : 'assets/images/fitcheck_logo_dark.png';

    final effectiveRadius = borderRadius ?? BorderRadius.circular(size * 0.2);

    Widget emblem = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dark ? Colors.black : Colors.white,
        borderRadius: effectiveRadius,
        border: border ??
            Border.all(
              color: dark ? FitCheckTheme.outlineVariant.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
              width: 1,
            ),
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) {
            // Elegant fallback icon if image fails
            return Container(
              color: dark ? FitCheckTheme.surfaceContainerHigh : const Color(0xFFF1F5F9),
              child: Center(
                child: Icon(
                  Icons.check_circle_outline,
                  color: FitCheckTheme.primary,
                  size: size * 0.6,
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!showWordmark) {
      if (onTap != null) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: onTap, child: emblem),
        );
      }
      return emblem;
    }

    final double effectiveWordmarkSize = wordmarkSize ?? (size * 0.6).clamp(14.0, 28.0);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(width: (size * 0.3).clamp(6.0, 12.0)),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FitCheck',
                  style: FitCheckTheme.headlineMedium(
                    color: dark ? FitCheckTheme.onSurface : const Color(0xFF0F172A),
                  ).copyWith(
                    fontSize: effectiveWordmarkSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(width: effectiveWordmarkSize * 0.3),
                Container(
                  width: (effectiveWordmarkSize * 0.3).clamp(4.0, 7.0),
                  height: (effectiveWordmarkSize * 0.3).clamp(4.0, 7.0),
                  decoration: const BoxDecoration(
                    color: FitCheckTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (showTagline) ...[
              const SizedBox(height: 1),
              Text(
                'GET FIT. CHECK FIT.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FitCheckTheme.labelSmall(
                  color: dark ? FitCheckTheme.onSurfaceVariant : const Color(0xFF64748B),
                ).copyWith(
                  fontSize: (effectiveWordmarkSize * 0.5).clamp(8.0, 10.0),
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );

    content = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: content,
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: content),
      );
    }
    return content;
  }
}
