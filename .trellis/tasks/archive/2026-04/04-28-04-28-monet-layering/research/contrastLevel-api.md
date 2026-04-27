# Research: Material 3 contrastLevel API

- **Query**: Does Flutter's `ColorScheme.fromSeed()` support a `contrastLevel` parameter? What values does it accept? How does it affect surface tokens?
- **Scope**: Internal (Flutter SDK source inspection)
- **Date**: 2026-04-28

## Findings

### API Signature

`ColorScheme.fromSeed()` supports `contrastLevel` since Flutter 3.22+. Located at:

`/Users/reborn/fvm/versions/3.38.9/packages/flutter/lib/src/material/color_scheme.dart` line 309-313:

```dart
factory ColorScheme.fromSeed({
  required Color seedColor,
  Brightness brightness = Brightness.light,
  DynamicSchemeVariant dynamicSchemeVariant = DynamicSchemeVariant.tonalSpot,
  double contrastLevel = 0.0,
  // ... all ColorScheme fields as optional overrides
})
```

### Accepted Values

- **Range**: `-1.0` to `1.0` inclusive
- **-1.0**: Lowest contrast (reduced)
- **0.0**: Default/normal contrast (standard Material 3 design spec)
- **0.5**: Medium contrast
- **1.0**: Highest contrast (maximum accessibility)
- Values between these breakpoints are linearly interpolated

The assertion (line 2180-2182):
```dart
assert(
  contrastLevel >= -1.0 && contrastLevel <= 1.0,
  'contrastLevel must be between -1.0 and 1.0 inclusive.',
);
```

### How contrastLevel Affects Surface Tokens

The `contrastLevel` is passed into `DynamicScheme`, which is then used by `MaterialDynamicColors` to compute surface token tones via `ContrastCurve`.

**ContrastCurve** (from `material_color_utilities-0.11.1/lib/dynamiccolor/src/contrast_curve.dart`) takes 4 values for contrast levels -1.0, 0.0, 0.5, and 1.0 respectively, and linearly interpolates between them.

#### Surface Token Tone Values at Each contrastLevel

For **light mode** (neutral palette):

| Token | contrastLevel=-1.0 | contrastLevel=0.0 | contrastLevel=0.5 | contrastLevel=1.0 |
|---|---|---|---|---|
| `surfaceDim` | 87 | 87 | 80 | 75 |
| `surfaceBright` | 98 (fixed) | 98 (fixed) | 98 (fixed) | 98 (fixed) |
| `surfaceContainerLowest` | 100 (fixed) | 100 (fixed) | 100 (fixed) | 100 (fixed) |
| `surfaceContainerLow` | 96 | 96 | 96 | 95 |
| `surfaceContainer` | 94 | 94 | 92 | 90 |
| `surfaceContainerHigh` | 92 | 92 | 88 | 85 |
| `surfaceContainerHighest` | 90 | 90 | 84 | 80 |

For **dark mode** (neutral palette):

| Token | contrastLevel=-1.0 | contrastLevel=0.0 | contrastLevel=0.5 | contrastLevel=1.0 |
|---|---|---|---|---|
| `surfaceDim` | 6 (fixed) | 6 (fixed) | 6 (fixed) | 6 (fixed) |
| `surfaceBright` | 24 | 24 | 29 | 34 |
| `surfaceContainerLowest` | 4 | 4 | 2 | 0 |
| `surfaceContainerLow` | 10 | 10 | 11 | 12 |
| `surfaceContainer` | 12 | 12 | 16 | 20 |
| `surfaceContainerHigh` | 17 | 17 | 21 | 25 |
| `surfaceContainerHighest` | 22 | 22 | 26 | 30 |

#### Analysis: Why Default contrastLevel=0.0 Causes "Flat" UI

At `contrastLevel=0.0`, many surface tokens share identical tone values with `contrastLevel=-1.0`:

**Light mode problems**:
- `surfaceDim` = 87 at both -1.0 and 0.0 (no change until 0.5)
- `surfaceContainerLow` = 96 at both -1.0 and 0.0 (no change until 1.0)
- `surfaceContainer` = 94 at both -1.0 and 0.0 (no change until 0.5)
- `surfaceContainerHigh` = 92 at both -1.0 and 0.0 (no change until 0.5)

This means the tonal spread between adjacent surface levels is very small:
- surface (98) -> surfaceContainerLow (96) = 2 tone delta
- surfaceContainerLow (96) -> surfaceContainer (94) = 2 tone delta
- surfaceContainer (94) -> surfaceContainerHigh (92) = 2 tone delta
- surfaceContainerHigh (92) -> surfaceContainerHighest (90) = 2 tone delta

At `contrastLevel=0.5` (medium), the spread widens:
- surface (98) -> surfaceContainerLow (96) = 2
- surfaceContainerLow (96) -> surfaceContainer (92) = 4
- surfaceContainer (92) -> surfaceContainerHigh (88) = 4
- surfaceContainerHigh (88) -> surfaceContainerHighest (84) = 4

At `contrastLevel=1.0` (high), the spread is maximum:
- surface (98) -> surfaceContainerLow (95) = 3
- surfaceContainerLow (95) -> surfaceContainer (90) = 5
- surfaceContainer (90) -> surfaceContainerHigh (85) = 5
- surfaceContainerHigh (85) -> surfaceContainerHighest (80) = 5

### ContrastCurve Interpolation Logic

```dart
// material_color_utilities ContrastCurve.get():
double get(double contrastLevel) {
  if (contrastLevel <= -1.0) return low;
  else if (contrastLevel < 0.0) return MathUtils.lerp(low, normal, (contrastLevel - (-1)) / 1);
  else if (contrastLevel < 0.5) return MathUtils.lerp(normal, medium, (contrastLevel - 0) / 0.5);
  else if (contrastLevel < 1.0) return MathUtils.lerp(medium, high, (contrastLevel - 0.5) / 0.5);
  else return high;
}
```

This means a value like `contrastLevel=0.25` interpolates between `normal` and `medium` at 50%.

### Applicability to Our Use Case

**LIMITATION**: `contrastLevel` only works with `ColorScheme.fromSeed()`. The `dynamic_color` plugin returns a pre-built `ColorScheme` from the OS CorePalette, which does NOT go through `ColorScheme.fromSeed()`. Therefore, this parameter cannot be directly used with Monet/dynamic color.

**However**, the `contrastLevel` logic is implemented in `material_color_utilities` and can be replicated by:
1. Extracting the `CorePalette` directly via `DynamicColorPlugin.getCorePalette()`
2. Building a `DynamicScheme` manually with `contrastLevel > 0`
3. Using `MaterialDynamicColors` to resolve each token from the scheme

### Related Specs

- `.trellis/spec/` -- Not yet checked

## Caveats / Not Found

- `contrastLevel` primarily affects foreground-on-background contrast (text readability), not just surface-to-surface tonal spread. The surface token tones do change, but the primary design intent is text contrast.
- Some surface tokens (surface, surfaceBright in light mode, surfaceDim in dark mode) are FIXED regardless of contrastLevel. The algorithm only adjusts the "container" variants.
- The `DynamicSchemeVariant` choice also affects how tones are calculated. `tonalSpot` (default) produces the most pastel result. `fidelity` matches seed color more closely.
