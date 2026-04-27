# Theme Guidelines

> Dynamic color pipeline and surface token conventions.

---

## Dynamic Color Pipeline

The app uses a **two-tier dynamic color pipeline** that bypasses the `dynamic_color` plugin's `DynamicColorBuilder`:

### Architecture

```
DynamicColorPlugin.getCorePalette()  ← Android 12+
          ↓ (null?)
DynamicColorPlugin.getAccentColor()  ← macOS / Windows / Linux
          ↓ (null?)
AppTheme.light / AppTheme.dark       ← static fallback
```

### Why not DynamicColorBuilder?

The plugin's `DynamicColorBuilder` uses the deprecated `Scheme` class which:
1. Does **not populate** `surfaceContainer*` tokens (Low, High, Highest, etc.)
2. Does **not support** `contrastLevel`
3. Falls back to Flutter defaults for missing tokens — producing flat, indistinguishable surfaces

### CorePalette + DynamicScheme Path (Android)

```dart
// dynamic_scheme_builder.dart
DynamicScheme buildSchemeFromCorePalette({
  required CorePalette palette,
  required bool isDark,
  double contrastLevel = 0.5,
}) { ... }

ColorScheme resolveColorScheme(DynamicScheme scheme) {
  // Resolves ALL 35 ColorScheme tokens via MaterialDynamicColors
}
```

Key: `contrastLevel: 0.5` elevates tonal spread between surface container levels, matching Android 14's built-in contrast algorithm.

### Accent Color Path (macOS/Windows/Linux)

```dart
ColorScheme.fromSeed(
  seedColor: accentColor,
  brightness: brightness,
  contrastLevel: kDefaultContrastLevel,  // 0.5
);
```

### Provider Structure

All dynamic color state lives in `theme_providers.dart`:

| Provider | Purpose |
|----------|---------|
| `corePaletteProvider` | Async fetch of OS CorePalette (Android 12+) |
| `accentColorProvider` | Async fetch of OS accent color (macOS/Win/Linux) |
| `dynamicColorAvailableProvider` | `true` if either source is non-null |
| `dynamicLightColorSchemeProvider` | Light ColorScheme with enhanced contrast |
| `dynamicDarkColorSchemeProvider` | Dark ColorScheme with enhanced contrast |

`app.dart` watches the scheme providers and falls back to `AppTheme.light` / `AppTheme.dark` when null.

---

## Surface Token Hierarchy

Material 3 surface tokens establish visual layering. Each level should be perceptibly distinct:

| Token | Typical Usage | Tone (light) |
|-------|---------------|-------------|
| `surface` | Nav bar, page background | 98 |
| `surfaceContainerLowest` | Elevated cards (enabled state) | 100 |
| `surfaceContainerLow` | Default card background | 95 |
| `surfaceContainer` | Mid-level containers | 91 |
| `surfaceContainerHigh` | Search bars, input fields | 86 |
| `surfaceContainerHighest` | Selected chips, export bars | 80 |

With `contrastLevel: 0.5`, adjacent levels have a **minimum 4-tone delta** instead of the default 2.

---

## Known Pitfalls

### material_color_utilities v0.11.1 naming

The member is `MaterialDynamicColors.inverseOnSurface`, NOT `onInverseSurface`. The `ColorScheme` constructor parameter is `onInverseSurface`, but the `MaterialDynamicColors` static property uses the old name.

### Static properties require class-name access

`MaterialDynamicColors` has static properties. Do NOT assign it to a variable:

```dart
// BAD — stores Type, not the class
final mdc = MaterialDynamicColors;
mdc.primary.getArgb(scheme); // Error: Type has no getter 'primary'

// GOOD — access statics on the class name directly
MaterialDynamicColors.primary.getArgb(scheme);
```

### CorePalette is not exported by dynamic_color

`CorePalette` comes from `material_color_utilities`, not `dynamic_color`. Add it as a direct dependency in `pubspec.yaml` — it's only a transitive dependency via `dynamic_color` by default.

---

## Contrast Level Reference

| Value | Effect |
|-------|--------|
| -1.0 | Reduced contrast (accessibility risk) |
| 0.0 | Default Android 14 behavior |
| 0.5 | **Project default** — enhanced surface separation |
| 1.0 | Maximum contrast |

The `kDefaultContrastLevel` constant in `dynamic_scheme_builder.dart` controls this globally.
