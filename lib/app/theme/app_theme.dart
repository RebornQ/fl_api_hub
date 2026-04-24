import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Application-wide Material 3 theme.
///
/// Uses [ColorScheme.fromSeed] with the brand primary color so that the
/// full tonal palette is generated automatically. Call [buildFromScheme] to
/// create a complete [ThemeData] from any [ColorScheme] (static or dynamic).
abstract final class AppTheme {
  /// Build a full [ThemeData] from the given [ColorScheme].
  ///
  /// Shared by both light and dark themes, and by dynamic (Monet) overrides.
  static ThemeData buildFromScheme(ColorScheme colorScheme) {
    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        color: colorScheme.surfaceContainerLow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  /// Static light theme using the brand seed color.
  static ThemeData get light => buildFromScheme(
    ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
  );

  /// Static dark theme using the brand seed color.
  static ThemeData get dark => buildFromScheme(
    ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
  );
}
