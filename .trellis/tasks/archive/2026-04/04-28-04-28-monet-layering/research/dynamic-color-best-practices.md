# Research: Flutter dynamic_color Plugin Best Practices for Tonal Contrast

- **Query**: How do other apps enhance surface token contrast when using the dynamic_color package? Any built-in APIs?
- **Scope**: Internal (code inspection) + External (package API)
- **Date**: 2026-04-28

## Findings

### Current Project Usage

The project uses `dynamic_color: ^1.7.0` (resolved to 1.8.1). The integration is in `lib/app/app.dart`:

```dart
// lib/app/app.dart line 30-34
final lightTheme = dynamicEnabled && lightDynamic != null
    ? AppTheme.buildFromScheme(lightDynamic.harmonized())
    : AppTheme.light;
final darkTheme = dynamicEnabled && darkDynamic != null
    ? AppTheme.buildFromScheme(darkDynamic.harmonized())
    : AppTheme.dark;
```

`DynamicColorBuilder` returns a `ColorScheme?` for light and dark. The `.harmonized()` call shifts error colors toward primary for cohesion.

### Key Problem: How DynamicColorBuilder Generates the ColorScheme

The `DynamicColorBuilder` (in `dynamic_color-1.8.1/lib/src/dynamic_color_builder.dart`) retrieves the `CorePalette` from the Android OS via `DynamicColorPlugin.getCorePalette()`, then converts it to `ColorScheme` using the `CorePaletteToColorScheme` extension.

**Critical finding**: The conversion uses the deprecated `Scheme.lightFromCorePalette()` / `Scheme.darkFromCorePalette()` methods, which use **hardcoded tone values** and do NOT support `contrastLevel`:

```dart
// corepalette_to_colorscheme.dart line 7-55
extension CorePaletteToColorScheme on CorePalette {
  ColorScheme toColorScheme({Brightness brightness = Brightness.light}) {
    final Scheme scheme;
    switch (brightness) {
      case Brightness.light:
        scheme = Scheme.lightFromCorePalette(this);
        break;
      case Brightness.dark:
        scheme = Scheme.darkFromCorePalette(this);
        break;
    }
    return ColorScheme(
      // ... uses scheme.surface, scheme.surfaceVariant, etc.
      // These are derived from fixed tone values: neutral.get(99), neutral.get(10), etc.
    );
  }
}
```

The `Scheme.lightFromCorePalette()` maps surface tokens to fixed neutral palette tones:
- `surface` = `neutral.get(99)` (light) / `neutral.get(10)` (dark)
- `surfaceVariant` = `neutralVariant.get(90)` (light) / `neutralVariant.get(30)` (dark)

These fixed tones produce very close colors, especially in the light theme (tone 99, 96, 94, 92, 90 are all nearly-white).

### Built-in APIs in the dynamic_color Package

The `dynamic_color` package provides:

1. **`ColorScheme.harmonized()`** -- Shifts error-family colors toward primary. Does NOT adjust surface contrast.
2. **`Color.harmonizeWith(Color)`** -- Blends a single color toward another. Could be used for custom adjustments.
3. **`CorePalette` extraction** -- `DynamicColorPlugin.getCorePalette()` gives direct access to the 5 tonal palettes.
4. **No built-in contrast enhancement API** -- The package does not expose any `contrastLevel` parameter.

### Files Found

| File Path | Description |
|---|---|
| `lib/app/app.dart` | DynamicColorBuilder integration |
| `lib/app/theme/app_theme.dart` | Theme construction from ColorScheme |
| `lib/core/widgets/section_card.dart` | Uses `surfaceContainerLow` for card background |
| `lib/features/settings/presentation/providers/theme_providers.dart` | Dynamic color toggle |
| `dynamic_color-1.8.1/lib/src/corepalette_to_colorscheme.dart` | CorePalette -> ColorScheme (hardcoded tones) |
| `dynamic_color-1.8.1/lib/src/dynamic_color_builder.dart` | DynamicColorBuilder widget |
| `dynamic_color-1.8.1/lib/src/harmonization.dart` | Harmonization extension |

### Related Specs

- `.trellis/spec/` -- Not yet checked for theme-related specs

## Caveats / Not Found

- The `dynamic_color` package has NO built-in API for adjusting surface token contrast. The `contrastLevel` parameter is only available in Flutter's own `ColorScheme.fromSeed()`, which is NOT used when Monet palette is provided.
- The `dynamic_color` package's `corepalette_to_colorscheme.dart` does NOT populate the newer surface tokens (`surfaceContainerLow`, `surfaceContainerHigh`, etc.) because it uses the deprecated `Scheme` class which only has `background`, `surface`, and `surfaceVariant`.
