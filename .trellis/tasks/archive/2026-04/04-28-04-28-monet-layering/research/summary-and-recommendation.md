# Research: Summary and Recommended Approach

- **Query**: Which approach to use for solving the Monet flat UI problem in this project?
- **Scope**: Synthesis of all research topics
- **Date**: 2026-04-28

## Problem Statement

When Monet (dynamic color) is enabled, the `DynamicColorBuilder` returns a `ColorScheme` where:
1. Surface container tokens (surfaceContainerLow, surfaceContainer, etc.) have tone deltas of only 2 points
2. The newer surface container tokens (surfaceDim, surfaceBright, surfaceContainerLowest through Highest) are NOT populated by `dynamic_color` v1.8.1 at all -- the plugin uses the deprecated `Scheme` class
3. Cards using `surfaceContainerLow` blend into the `surface` background

## Root Cause Analysis

1. **`DynamicColorBuilder` uses deprecated `Scheme` class**: `corepalette_to_colorscheme.dart` calls `Scheme.lightFromCorePalette()` / `Scheme.darkFromCorePalette()`, which only populates `background`, `surface`, and `surfaceVariant` (no container variants).

2. **No contrastLevel control**: The deprecated `Scheme` class does not support `contrastLevel`. The OS palette tones are hardcoded.

3. **Flutter fills gaps with defaults**: When the dynamic `ColorScheme` does not set `surfaceContainerLow` etc., Flutter's `ThemeData` uses fallback values from `ColorScheme.light()` / `ColorScheme.dark()`, which have their own (also flat) surface token values.

## Recommended Approach

**Hybrid: CorePalette extraction + DynamicScheme with elevated contrastLevel**

Steps:
1. Replace `DynamicColorBuilder` usage with direct `DynamicColorPlugin.getCorePalette()` call
2. Build a `DynamicScheme` from the OS CorePalette with `contrastLevel: 0.5` (medium)
3. Resolve all color tokens via `MaterialDynamicColors` from the scheme
4. Cache the result and rebuild theme when palette changes

This approach:
- Preserves the wallpaper-derived hue/chroma (brand tinting on surfaces)
- Provides proper tonal spread between surface container levels
- Populates ALL M3 surface tokens correctly
- Uses the same algorithm that Android 14 uses for its contrast setting
- Works with `material_color_utilities` package already in the dependency tree

## Alternative (Simpler, Less Precise)

If the full DynamicScheme approach is too complex:
1. Extract `CorePalette` from the plugin
2. Use `ColorScheme.fromSeed(seedColor: Color(palette.primary.get(40)), contrastLevel: 0.5)` 
3. Override primary/secondary/tertiary containers to match OS palette
4. Accept that surface tones will come from a generated palette, not the exact wallpaper palette

## Files to Modify (Implementation Plan)

| File | Change |
|---|---|
| `lib/app/app.dart` | Replace `DynamicColorBuilder` with async CorePalette fetching |
| `lib/app/theme/app_theme.dart` | Add `buildFromCorePalette()` method |
| New: `lib/app/theme/dynamic_scheme_builder.dart` | Utility to build ColorScheme from CorePalette with contrastLevel |
| `lib/features/settings/presentation/providers/theme_providers.dart` | May need provider for CorePalette state |

## Related Research Files

- `research/dynamic-color-best-practices.md` -- dynamic_color plugin internals
- `research/contrastLevel-api.md` -- contrastLevel parameter details and tone tables
- `research/colorscheme-manipulation-approaches.md` -- 5 approach comparison
- `research/corepalette-surface-reconstruction.md` -- CorePalette reconstruction techniques
- `research/android-monet-contrast-patterns.md` -- AOSP patterns

## Caveats

- `material_color_utilities` is a transitive dependency (via `dynamic_color`). Importing it directly is safe but the version is pinned to 0.11.1 by `dynamic_color`.
- The `DynamicScheme` constructor is available in the `material_color_utilities` package but is not re-exported by `dynamic_color`. A direct import of `package:material_color_utilities/material_color_utilities.dart` is needed.
- Testing the visual result requires running on an Android device with dynamic color support, or using the `CorePalette.of()` constructor with a test color to simulate.
