import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Default contrast level for dynamic color schemes.
///
/// Range: -1.0 (reduced) to 1.0 (high). Android 14 default is 0.0;
/// 0.5 provides noticeably better surface token separation without
/// being overly dramatic.
const kDefaultContrastLevel = 0.5;

/// Builds a [DynamicScheme] from the OS [CorePalette] with an elevated
/// [contrastLevel] to ensure surface container tokens have sufficient
/// tonal spread.
DynamicScheme buildSchemeFromCorePalette({
  required CorePalette palette,
  required bool isDark,
  double contrastLevel = kDefaultContrastLevel,
}) {
  return DynamicScheme(
    sourceColorArgb: palette.primary.get(40),
    variant: Variant.tonalSpot,
    contrastLevel: contrastLevel,
    isDark: isDark,
    primaryPalette: palette.primary,
    secondaryPalette: palette.secondary,
    tertiaryPalette: palette.tertiary,
    neutralPalette: palette.neutral,
    neutralVariantPalette: palette.neutralVariant,
  );
}

/// Resolves a [DynamicScheme] into a Flutter [ColorScheme], using
/// [MaterialDynamicColors] to ensure every token (including all
/// surfaceContainer variants) is populated.
ColorScheme resolveColorScheme(DynamicScheme scheme) {
  return ColorScheme(
    brightness: scheme.isDark ? Brightness.dark : Brightness.light,
    primary: Color(MaterialDynamicColors.primary.getArgb(scheme)),
    onPrimary: Color(MaterialDynamicColors.onPrimary.getArgb(scheme)),
    primaryContainer: Color(
      MaterialDynamicColors.primaryContainer.getArgb(scheme),
    ),
    onPrimaryContainer: Color(
      MaterialDynamicColors.onPrimaryContainer.getArgb(scheme),
    ),
    secondary: Color(MaterialDynamicColors.secondary.getArgb(scheme)),
    onSecondary: Color(MaterialDynamicColors.onSecondary.getArgb(scheme)),
    secondaryContainer: Color(
      MaterialDynamicColors.secondaryContainer.getArgb(scheme),
    ),
    onSecondaryContainer: Color(
      MaterialDynamicColors.onSecondaryContainer.getArgb(scheme),
    ),
    tertiary: Color(MaterialDynamicColors.tertiary.getArgb(scheme)),
    onTertiary: Color(MaterialDynamicColors.onTertiary.getArgb(scheme)),
    tertiaryContainer: Color(
      MaterialDynamicColors.tertiaryContainer.getArgb(scheme),
    ),
    onTertiaryContainer: Color(
      MaterialDynamicColors.onTertiaryContainer.getArgb(scheme),
    ),
    error: Color(MaterialDynamicColors.error.getArgb(scheme)),
    onError: Color(MaterialDynamicColors.onError.getArgb(scheme)),
    errorContainer: Color(MaterialDynamicColors.errorContainer.getArgb(scheme)),
    onErrorContainer: Color(
      MaterialDynamicColors.onErrorContainer.getArgb(scheme),
    ),
    surface: Color(MaterialDynamicColors.surface.getArgb(scheme)),
    onSurface: Color(MaterialDynamicColors.onSurface.getArgb(scheme)),
    surfaceDim: Color(MaterialDynamicColors.surfaceDim.getArgb(scheme)),
    surfaceBright: Color(MaterialDynamicColors.surfaceBright.getArgb(scheme)),
    surfaceContainerLowest: Color(
      MaterialDynamicColors.surfaceContainerLowest.getArgb(scheme),
    ),
    surfaceContainerLow: Color(
      MaterialDynamicColors.surfaceContainerLow.getArgb(scheme),
    ),
    surfaceContainer: Color(
      MaterialDynamicColors.surfaceContainer.getArgb(scheme),
    ),
    surfaceContainerHigh: Color(
      MaterialDynamicColors.surfaceContainerHigh.getArgb(scheme),
    ),
    surfaceContainerHighest: Color(
      MaterialDynamicColors.surfaceContainerHighest.getArgb(scheme),
    ),
    onSurfaceVariant: Color(
      MaterialDynamicColors.onSurfaceVariant.getArgb(scheme),
    ),
    outline: Color(MaterialDynamicColors.outline.getArgb(scheme)),
    outlineVariant: Color(MaterialDynamicColors.outlineVariant.getArgb(scheme)),
    inverseSurface: Color(MaterialDynamicColors.inverseSurface.getArgb(scheme)),
    onInverseSurface: Color(
      MaterialDynamicColors.inverseOnSurface.getArgb(scheme),
    ),
    inversePrimary: Color(MaterialDynamicColors.inversePrimary.getArgb(scheme)),
    shadow: Color(MaterialDynamicColors.shadow.getArgb(scheme)),
    scrim: Color(MaterialDynamicColors.scrim.getArgb(scheme)),
    surfaceTint: Color(MaterialDynamicColors.primary.getArgb(scheme)),
  );
}
