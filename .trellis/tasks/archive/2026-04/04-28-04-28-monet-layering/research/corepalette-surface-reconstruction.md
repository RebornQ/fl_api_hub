# Research: Custom Surface Colors via CorePalette

- **Query**: Can you extract the tonal palette from dynamic color and manually reconstruct surface tokens with guaranteed minimum contrast?
- **Scope**: Internal (source code analysis)
- **Date**: 2026-04-28

## Findings

### CorePalette Structure from Android Monet

When `DynamicColorPlugin.getCorePalette()` is called on Android 12+ (API 31+), the OS returns a `CorePalette` containing 5 `TonalPalette` objects. Each palette provides 13 tones (0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100) for a constant hue/chroma combination.

```dart
// CorePalette structure:
class CorePalette {
  final TonalPalette primary;         // Brand color, high chroma
  final TonalPalette secondary;       // Brand hue, low chroma (16)
  final TonalPalette tertiary;        // Shifted hue, medium chroma (24)
  final TonalPalette neutral;         // Brand hue, very low chroma (4)
  final TonalPalette neutralVariant;  // Brand hue, low chroma (8)
  final TonalPalette error;           // Fixed: hue 25, chroma 84
}
```

The `neutral` palette is the source of all surface tokens. The `neutralVariant` palette provides `surfaceVariant`, `onSurfaceVariant`, `outline`, and `outlineVariant`.

### TonalPalette API

`TonalPalette.get(int tone)` returns an ARGB int for any tone value 0-100:

```dart
// TonalPalette.get() - line 170
int get(int tone) {
  return _cache.putIfAbsent(
    tone,
    () => Hct.from(hue, chroma, tone.toDouble()).toInt(),
  );
}
```

This means you can request ANY tone, not just the 13 common tones. For example, `neutral.get(94)` returns the neutral palette color at tone 94, even though 94 is not in `commonTones`.

### Reconstructing Surface Tokens with Guaranteed Minimum Contrast

**Recommended approach**: Define custom tone mappings with forced minimum deltas between adjacent surface levels.

```dart
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Minimum tone delta between adjacent surface levels.
const _minToneDelta = 4;

/// Custom surface tone mapping for enhanced contrast.
class EnhancedSurfaceTones {
  final bool isDark;

  EnhancedSurfaceTones({required this.isDark});

  // Light mode: tone decreases (darker) as container level increases
  // Dark mode: tone increases (lighter) as container level increases

  int get surface => isDark ? 6 : 98;

  int get surfaceDim => isDark ? 6 : 85;  // More aggressive than default 87

  int get surfaceBright => isDark ? 30 : 98;  // More aggressive than default 24

  int get surfaceContainerLowest => isDark ? 0 : 100;

  int get surfaceContainerLow => isDark ? 10 : 95;

  int get surfaceContainer => isDark ? 16 : 91;   // 4 gap from Low

  int get surfaceContainerHigh => isDark ? 22 : 86;  // 5 gap

  int get surfaceContainerHighest => isDark ? 28 : 80;  // 6 gap
}

ColorScheme buildEnhancedScheme(CorePalette palette, Brightness brightness) {
  final tones = EnhancedSurfaceTones(isDark: brightness == Brightness.dark);
  final n = palette.neutral;
  final nv = palette.neutralVariant;

  return ColorScheme(
    brightness: brightness,
    // Primary colors from OS palette
    primary: Color(palette.primary.get(brightness == Brightness.dark ? 80 : 40)),
    onPrimary: Color(palette.primary.get(brightness == Brightness.dark ? 20 : 100)),
    primaryContainer: Color(palette.primary.get(brightness == Brightness.dark ? 30 : 90)),
    onPrimaryContainer: Color(palette.primary.get(brightness == Brightness.dark ? 90 : 10)),
    // Secondary colors from OS palette
    secondary: Color(palette.secondary.get(brightness == Brightness.dark ? 80 : 40)),
    onSecondary: Color(palette.secondary.get(brightness == Brightness.dark ? 20 : 100)),
    secondaryContainer: Color(palette.secondary.get(brightness == Brightness.dark ? 30 : 90)),
    onSecondaryContainer: Color(palette.secondary.get(brightness == Brightness.dark ? 90 : 10)),
    // Tertiary colors from OS palette
    tertiary: Color(palette.tertiary.get(brightness == Brightness.dark ? 80 : 40)),
    onTertiary: Color(palette.tertiary.get(brightness == Brightness.dark ? 20 : 100)),
    tertiaryContainer: Color(palette.tertiary.get(brightness == Brightness.dark ? 30 : 90)),
    onTertiaryContainer: Color(palette.tertiary.get(brightness == Brightness.dark ? 90 : 10)),
    // Error colors
    error: Color(palette.error.get(brightness == Brightness.dark ? 80 : 40)),
    onError: Color(palette.error.get(brightness == Brightness.dark ? 20 : 100)),
    errorContainer: Color(palette.error.get(brightness == Brightness.dark ? 30 : 90)),
    onErrorContainer: Color(palette.error.get(brightness == Brightness.dark ? 90 : 10)),
    // Enhanced surface tokens
    surface: Color(n.get(tones.surface)),
    surfaceDim: Color(n.get(tones.surfaceDim)),
    surfaceBright: Color(n.get(tones.surfaceBright)),
    surfaceContainerLowest: Color(n.get(tones.surfaceContainerLowest)),
    surfaceContainerLow: Color(n.get(tones.surfaceContainerLow)),
    surfaceContainer: Color(n.get(tones.surfaceContainer)),
    surfaceContainerHigh: Color(n.get(tones.surfaceContainerHigh)),
    surfaceContainerHighest: Color(n.get(tones.surfaceContainerHighest)),
    onSurface: Color(n.get(brightness == Brightness.dark ? 90 : 10)),
    onSurfaceVariant: Color(nv.get(brightness == Brightness.dark ? 80 : 30)),
    outline: Color(nv.get(brightness == Brightness.dark ? 60 : 50)),
    outlineVariant: Color(nv.get(brightness == Brightness.dark ? 30 : 80)),
    inverseSurface: Color(n.get(brightness == Brightness.dark ? 90 : 20)),
    onInverseSurface: Color(n.get(brightness == Brightness.dark ? 20 : 95)),
    inversePrimary: Color(palette.primary.get(brightness == Brightness.dark ? 40 : 80)),
    shadow: Color(n.get(0)),
    scrim: Color(n.get(0)),
    surfaceTint: Color(palette.primary.get(brightness == Brightness.dark ? 80 : 40)),
  );
}
```

### Hybrid Approach: ContrastCurve-based with OS Palettes

The most principled approach is to construct a `DynamicScheme` using the OS palettes and a custom `contrastLevel`:

```dart
import 'package:material_color_utilities/material_color_utilities.dart';

DynamicScheme buildSchemeFromOsPalette({
  required CorePalette palette,
  required bool isDark,
  required double contrastLevel,
}) {
  // Derive source color from the primary palette at tone 40
  final sourceColorHct = Hct.fromInt(palette.primary.get(40));

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

// Then use MaterialDynamicColors to resolve each token:
ColorScheme resolveFromScheme(DynamicScheme scheme) {
  return ColorScheme(
    brightness: scheme.isDark ? Brightness.dark : Brightness.light,
    primary: Color(MaterialDynamicColors.primary.getArgb(scheme)),
    surface: Color(MaterialDynamicColors.surface.getArgb(scheme)),
    surfaceDim: Color(MaterialDynamicColors.surfaceDim.getArgb(scheme)),
    surfaceBright: Color(MaterialDynamicColors.surfaceBright.getArgb(scheme)),
    surfaceContainerLowest: Color(MaterialDynamicColors.surfaceContainerLowest.getArgb(scheme)),
    surfaceContainerLow: Color(MaterialDynamicColors.surfaceContainerLow.getArgb(scheme)),
    surfaceContainer: Color(MaterialDynamicColors.surfaceContainer.getArgb(scheme)),
    surfaceContainerHigh: Color(MaterialDynamicColors.surfaceContainerHigh.getArgb(scheme)),
    surfaceContainerHighest: Color(MaterialDynamicColors.surfaceContainerHighest.getArgb(scheme)),
    onSurface: Color(MaterialDynamicColors.onSurface.getArgb(scheme)),
    onSurfaceVariant: Color(MaterialDynamicColors.onSurfaceVariant.getArgb(scheme)),
    // ... all other tokens
  );
}
```

**This approach** gives you:
1. The OS wallpaper-derived hue/chroma in the neutral palette
2. The `ContrastCurve`-based tone selection with elevated `contrastLevel`
3. All M3 surface container tokens properly populated

### Files Found

| File Path | Description |
|---|---|
| `material_color_utilities-0.11.1/lib/palettes/core_palette.dart` | CorePalette with 5 TonalPalettes |
| `material_color_utilities-0.11.1/lib/palettes/tonal_palette.dart` | TonalPalette.get(tone) for any tone 0-100 |
| `material_color_utilities-0.11.1/lib/dynamiccolor/dynamic_scheme.dart` | DynamicScheme constructor accepting palettes + contrastLevel |
| `material_color_utilities-0.11.1/lib/dynamiccolor/material_dynamic_colors.dart` | Token resolution using ContrastCurve |
| `dynamic_color-1.8.1/lib/src/dynamic_color_plugin.dart` | getCorePalette() direct API |

## Caveats / Not Found

- The `DynamicScheme` constructor's `variant` parameter is used by some scheme variants to rotate hues. When providing OS palettes directly, the variant selection may not matter for neutral/surface tokens (which don't use hue rotation), but it could affect primary/secondary colors. Using `Variant.tonalSpot` is safest.
- The OS `CorePalette` neutral palette has very low chroma (typically 2-4), meaning the HCT `get(tone)` may produce slightly different colors than the cached tones returned by Android. The `TonalPalette.fromList()` constructor (used by `CorePalette.fromList()`) caches the 13 common tones from the OS and generates others from deduced hue/chroma.
- No third-party Flutter package was found that specifically addresses Monet surface contrast enhancement. This is a gap in the ecosystem.
