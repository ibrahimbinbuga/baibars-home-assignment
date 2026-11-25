import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'spacing.dart';
import 'status_colors.dart';

/// Type scale (Tokens.dc.html). Body never below 14 px; 12 px only for bold labels.
abstract final class AppText {
  static const _font = 'Inter';

  static TextStyle _style(double size, double lineHeight, FontWeight weight) =>
      TextStyle(
        fontFamily: _font,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: AppPalette.onSurface,
      );

  static final headlineMedium = _style(28, 36, FontWeight.w700);
  static final titleLarge = _style(22, 28, FontWeight.w700);
  static final titleMedium = _style(18, 24, FontWeight.w700);
  static final titleSmall = _style(16, 24, FontWeight.w700);
  static final bodyLarge = _style(16, 24, FontWeight.w400);
  static final bodyMedium = _style(14, 20, FontWeight.w400);
  static final labelLarge = _style(15, 20, FontWeight.w600);
  static final labelMedium = _style(13, 18, FontWeight.w600);
  static final labelSmall = _style(12, 16, FontWeight.w700);

  /// Big live value in metric tiles (26/32 · 700), tabular figures.
  static final metricValue = tabular(_style(26, 32, FontWeight.w700));

  static const _tabularFigures = [FontFeature.tabularFigures()];

  /// Tabular figures for every live value, so numbers don't jiggle as they change.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabularFigures);
}

abstract final class AppTheme {
  static final scheme = const ColorScheme.light(
    primary: AppPalette.primary,
    onPrimary: AppPalette.onPrimary,
    primaryContainer: AppPalette.primaryContainer,
    onPrimaryContainer: AppPalette.onSurface,
    surface: AppPalette.surface,
    onSurface: AppPalette.onSurface,
    onSurfaceVariant: AppPalette.onSurfaceVariant,
    surfaceContainerLow: AppPalette.background,
    surfaceContainerHighest: AppPalette.muted,
    outline: AppPalette.outline,
    outlineVariant: AppPalette.outlineVariant,
    error: AppPalette.error,
    errorContainer: AppPalette.errorContainer,
    inverseSurface: AppPalette.inverseSurface,
  );

  static ThemeData light() {
    final textTheme = TextTheme(
      headlineMedium: AppText.headlineMedium,
      titleLarge: AppText.titleLarge,
      titleMedium: AppText.titleMedium,
      titleSmall: AppText.titleSmall,
      bodyLarge: AppText.bodyLarge,
      bodyMedium: AppText.bodyMedium,
      labelLarge: AppText.labelLarge,
      labelMedium: AppText.labelMedium,
      labelSmall: AppText.labelSmall,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      textTheme: textTheme,
      scaffoldBackgroundColor: AppPalette.background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const [StatusColors.light],
      dividerTheme: const DividerThemeData(
        color: AppPalette.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.labelMedium.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppPalette.onSurface
                : AppPalette.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppPalette.onSurface
                : AppPalette.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: AppText.bodyLarge.copyWith(
          color: AppPalette.onSurfaceVariant,
        ),
        border: _inputBorder(AppPalette.outline, 1),
        enabledBorder: _inputBorder(AppPalette.outline, 1),
        disabledBorder: _inputBorder(AppPalette.outlineVariant, 1),
        focusedBorder: _inputBorder(AppPalette.primary, 2),
        errorBorder: _inputBorder(AppPalette.error, 2),
        focusedErrorBorder: _inputBorder(AppPalette.error, 2),
        errorStyle: AppText.labelMedium.copyWith(color: AppPalette.error),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.inverseSurface,
        contentTextStyle: AppText.bodyMedium.copyWith(
          color: AppPalette.onPrimary,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
}
