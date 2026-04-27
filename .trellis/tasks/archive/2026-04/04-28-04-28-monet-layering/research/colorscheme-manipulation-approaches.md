# Research: Custom ColorScheme Manipulation Approaches

- **Query**: Techniques for enhancing surface token contrast in dynamically generated ColorSchemes (HSL/OKLCH adjustments, manual tonal palette generation, CorePalette reconstruction)
- **Scope**: Internal (Flutter SDK + material_color_utilities source) + External (community patterns)
- **Date**: 2026-04-28

## Findings

### Approach 1: HSL/HSLk Lightness Adjustment on Surface Tokens

**What**: After receiving the dynamic `ColorScheme` from `DynamicColorBuilder`, adjust specific surface tokens by converting to HSL and shifting lightness.

**Technique**:
```dart
ColorScheme enhanceSurfaceContrast(ColorScheme scheme) {
  return scheme.copyWith(
    surfaceContainerLow: _shiftLightness(scheme.surfaceContainerLow, -2),
    surfaceContainer: _shiftLightness(scheme.surfaceContainer, -4),
    surfaceContainerHigh: _shiftLightness(scheme.surfaceContainerHigh, -6),
    surfaceContainerHighest: _shiftLightness(scheme.surfaceContainerHighest, -8),
  );
}

Color _shiftLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta / 100).clamp(0.0, 1.0)).toColor();
}
```

**Pros**:
- Simple to implement
- No additional dependencies
- Works on any ColorScheme regardless of source

**Cons**:
- HSL lightness is not perceptually uniform -- a shift of 2% at high lightness (near-white) produces a different visual delta than at 50% lightness
- Can produce off-hue colors (HSL shifts can drift hue slightly)
- Does not leverage the underlying tonal palette information
- Manual tuning required -- no guarantee of accessible contrast ratios

**Applicability**: Quick fix but not robust for production. Better approaches exist.

---

### Approach 2: CorePalette Extraction + DynamicScheme with contrastLevel

**What**: Instead of using `DynamicColorBuilder`'s built-in `CorePaletteToColorScheme` conversion, extract the `CorePalette` directly and build a `DynamicScheme` with an elevated `contrastLevel`, then resolve surface tokens using `MaterialDynamicColors`.

**Technique**:
```dart
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:dynamic_color/dynamic_color.dart';

Future<ColorScheme> buildEnhancedDynamicScheme({
  required Brightness brightness,
  double contrastLevel = 0.5,
}) async {
  final CorePalette? corePalette = await DynamicColorPlugin.getCorePalette();
  if (corePalette == null) {
    // Fallback to static scheme
    return ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
  }

  // Build DynamicScheme from the OS CorePalette with elevated contrastLevel
  final isDark = brightness == Brightness.dark;
  final sourceColorHct = Hct.fromInt(corePalette.primary.get(40));

  final scheme = SchemeTonalSpot(
    sourceColorHct: sourceColorHct,
    isDark: isDark,
    contrastLevel: contrastLevel,  // 0.5 for medium, 1.0 for high
  );

  // Use the exact same resolution as ColorScheme.fromSeed
  return ColorScheme(
    primary: Color(MaterialDynamicColors.primary.getArgb(scheme)),
    onPrimary: Color(MaterialDynamicColors.onPrimary.getArgb(scheme)),
    // ... all tokens resolved from scheme with contrastLevel
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
    // ... remaining tokens
    brightness: brightness,
  );
}
```

**Critical detail about CorePalette and DynamicScheme**:

The `DynamicScheme` constructor requires full `TonalPalette` objects for primary, secondary, tertiary, neutral, and neutralVariant. The `CorePalette` from the OS provides exactly these:

```dart
// CorePalette fields:
final TonalPalette primary;
final TonalPalette secondary;
final TonalPalette tertiary;
final TonalPalette neutral;
final TonalPalette neutralVariant;
```

A `SchemeTonalSpot` (or any variant) can be constructed with these palettes:

```dart
// SchemeTonalSpot extends DynamicScheme
// DynamicScheme constructor takes:
DynamicScheme({
  required this.sourceColorArgb,
  required this.variant,
  this.contrastLevel = 0.0,
  required this.isDark,
  required this.primaryPalette,
  required this.secondaryPalette,
  required this.tertiaryPalette,
  required this.neutralPalette,
  required this.neutralVariantPalette,
})
```

**Pros**:
- Uses the same algorithm Flutter uses internally for `ColorScheme.fromSeed()`
- `contrastLevel` directly controls surface token tonal spread
- Produces accessible contrast ratios automatically
- Respects the OS color palette (wallpaper-derived)
- Full access to all M3 surface tokens (surfaceContainerLow, etc.)

**Cons**:
- Requires importing `material_color_utilities` directly
- Must construct the full ColorScheme manually (all ~40 color tokens)
- Need to check if `SchemeTonalSpot` correctly handles the OS CorePalette's palettes (they may have different hue/chroma than what `SchemeTonalSpot` would generate itself)
- More code to maintain

**Applicability**: This is the most architecturally sound approach. It directly addresses the root cause by applying the Material 3 contrast algorithm to the OS palette.

---

### Approach 3: Using `ColorScheme.fromSeed()` with contrastLevel as Override

**What**: Extract the seed color from the dynamic palette, then use `ColorScheme.fromSeed()` with `contrastLevel` and override specific surface tokens back to dynamic values.

**Technique**:
```dart
ColorScheme fromDynamicWithContrast(CorePalette palette, Brightness brightness) {
  // Get the seed color from the OS palette
  final seedColor = Color(palette.primary.get(40));

  // Generate scheme with contrastLevel from seed
  final enhanced = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    contrastLevel: 0.5,
    // Override key brand colors to match OS palette exactly
    primary: Color(palette.primary.get(40)),
    primaryContainer: Color(palette.primary.get(90)),
    secondary: Color(palette.secondary.get(40)),
    secondaryContainer: Color(palette.secondary.get(90)),
    tertiary: Color(palette.tertiary.get(40)),
    tertiaryContainer: Color(palette.tertiary.get(90)),
  );
  return enhanced;
}
```

**Pros**:
- Simplest code -- leverages `ColorScheme.fromSeed()` which handles all token resolution
- `contrastLevel` works automatically for surface tokens
- Can still override brand colors to match OS palette

**Cons**:
- The seed color may not perfectly reproduce the OS palette's exact hues/chromas
- The neutral palette generated by `fromSeed()` may differ from the OS neutral palette
- Surface tones come from a generated neutral palette, not the OS one -- this means the wallpaper's tonal influence on surfaces is lost

**Applicability**: Good compromise if preserving exact OS surface tinting is less important than having proper contrast hierarchy. The surface colors will be derived from the seed color's tonal palette rather than the wallpaper's neutral palette.

---

### Approach 4: Manual Tone Forcing with TonalPalette.get()

**What**: Extract `CorePalette.neutral` and `CorePalette.neutralVariant` tonal palettes, then force surface tokens to specific tones with guaranteed minimum deltas.

**Technique**:
```dart
ColorScheme forceSurfaceTones(CorePalette palette, Brightness brightness) {
  final n = palette.neutral;   // neutral TonalPalette
  final nv = palette.neutralVariant;  // neutral variant TonalPalette

  if (brightness == Brightness.light) {
    return ColorScheme(
      // Keep dynamic primary/secondary/tertiary colors...
      surface: Color(n.get(99)),
      surfaceDim: Color(n.get(92)),         // Force tone 92 instead of 87
      surfaceBright: Color(n.get(98)),
      surfaceContainerLowest: Color(n.get(100)),
      surfaceContainerLow: Color(n.get(96)),
      surfaceContainer: Color(n.get(93)),    // 3 tone gap from Low
      surfaceContainerHigh: Color(n.get(89)), // 4 tone gap
      surfaceContainerHighest: Color(n.get(85)), // 4 tone gap
      // ...
    );
  } else {
    // dark mode...
  }
}
```

**Pros**:
- Full control over every surface token
- Uses the actual OS neutral palette (preserves wallpaper tinting)
- Guaranteed minimum tone deltas between levels

**Cons**:
- Manual tuning required
- Must handle light/dark separately
- Does not automatically adapt to accessibility needs
- More verbose code

**Applicability**: Good when you want precise control and want to preserve the wallpaper's color influence on surfaces.

---

### Approach 5: Using `DynamicColorPlugin.getCorePalette()` directly

**What**: Replace `DynamicColorBuilder` with a direct call to `DynamicColorPlugin.getCorePalette()` and build the full ColorScheme using Approach 2 or 4.

**Current `DynamicColorBuilder` limitations**:
- Returns `ColorScheme?` with no `contrastLevel` control
- Uses deprecated `Scheme` class internally (no surfaceContainer tokens)
- Does not populate: `surfaceDim`, `surfaceBright`, `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest` -- these all fall back to defaults

**Code to access CorePalette directly**:
```dart
import 'package:dynamic_color/dynamic_color.dart';

// In initState or similar:
CorePalette? corePalette = await DynamicColorPlugin.getCorePalette();
// Then build scheme using approaches 2 or 4
```

### Files Found

| File Path | Description |
|---|---|
| `material_color_utilities-0.11.1/lib/palettes/core_palette.dart` | CorePalette with neutral/neutralVariant TonalPalettes |
| `material_color_utilities-0.11.1/lib/palettes/tonal_palette.dart` | TonalPalette.get(tone) for exact tone extraction |
| `material_color_utilities-0.11.1/lib/dynamiccolor/material_dynamic_colors.dart` | All surface token tone definitions with ContrastCurve |
| `material_color_utilities-0.11.1/lib/dynamiccolor/dynamic_scheme.dart` | DynamicScheme with contrastLevel field |
| `material_color_utilities-0.11.1/lib/dynamiccolor/src/contrast_curve.dart` | ContrastCurve interpolation logic |
| `material_color_utilities-0.11.1/lib/scheme/scheme_tonal_spot.dart` | SchemeTonalSpot constructor |
| `dynamic_color-1.8.1/lib/src/dynamic_color_plugin.dart` | getCorePalette() API |

## Caveats / Not Found

- OKLCH color space is not directly available in Flutter/Dart without a third-party package. HSL and HCT are the available options.
- The `SchemeTonalSpot` and other scheme variant constructors may expect specific palette configurations. Using OS-derived palettes directly may produce slightly different results than the standard flow.
- Need to verify that `DynamicColorPlugin.getCorePalette()` returns the same `CorePalette` that `DynamicColorBuilder` uses internally (it does, per source code inspection).
