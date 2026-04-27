library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../../../app/theme/dynamic_scheme_builder.dart';
import '../../data/datasources/theme_local_datasource.dart' as data;
import '../../data/repositories/theme_repository_impl.dart';
import '../../domain/entities/theme_preference.dart';
import '../../domain/repositories/theme_repository.dart';
import 'theme_notifier.dart';

// --- Repository providers ---

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepositoryImpl(ref.read(data.themeLocalDataSourceProvider));
});

// --- Core state ---

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemePreference>(
  ThemeNotifier.new,
);

// --- Derived providers ---

/// Maps [AppThemeMode] to Flutter's [ThemeMode].
final themeModeProvider = Provider<ThemeMode>((ref) {
  final asyncPref = ref.watch(themeProvider);
  return asyncPref
          .whenData(
            (p) => switch (p.themeMode) {
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
              AppThemeMode.system => ThemeMode.system,
            },
          )
          .valueOrNull ??
      ThemeMode.system;
});

/// Whether dynamic color (Monet) is enabled by the user.
final dynamicColorEnabledProvider = Provider<bool>((ref) {
  final asyncPref = ref.watch(themeProvider);
  return asyncPref.valueOrNull?.dynamicColorEnabled ?? true;
});

/// OS-level [CorePalette] fetched via the dynamic_color plugin.
///
/// Resolves to `null` on platforms that do not support Monet (Android 12+).
final corePaletteProvider = FutureProvider<CorePalette?>((ref) async {
  try {
    return DynamicColorPlugin.getCorePalette();
  } catch (_) {
    return null;
  }
});

/// OS-level accent [Color] fetched via the dynamic_color plugin.
///
/// Supported on macOS 10.14+, Windows Vista+, and GTK-based Linux desktops.
final accentColorProvider = FutureProvider<Color?>((ref) async {
  try {
    return DynamicColorPlugin.getAccentColor();
  } catch (_) {
    return null;
  }
});

/// Whether the current platform supports dynamic color (Monet / accent color).
///
/// Derived from [corePaletteProvider] and [accentColorProvider]; `true` when
/// either is available.
final dynamicColorAvailableProvider = Provider<bool>((ref) {
  final hasPalette =
      ref.watch(corePaletteProvider).whenOrNull(data: (p) => p != null) ??
      false;
  final hasAccent =
      ref.watch(accentColorProvider).whenOrNull(data: (c) => c != null) ??
      false;
  return hasPalette || hasAccent;
});

/// Resolves a dynamic [ColorScheme] for the given [brightness].
///
/// Priority:
/// 1. CorePalette (Android 12+) → DynamicScheme with contrastLevel 0.5
/// 2. Accent color (macOS/Windows/Linux) → ColorScheme.fromSeed with contrastLevel 0.5
/// 3. `null` → static fallback
ColorScheme? _resolveDynamicScheme(Ref ref, Brightness brightness) {
  final enabled = ref.watch(dynamicColorEnabledProvider);
  if (!enabled) return null;

  final asyncPalette = ref.watch(corePaletteProvider);
  final palette = asyncPalette.whenOrNull(data: (p) => p);
  if (palette != null) {
    return resolveColorScheme(
      buildSchemeFromCorePalette(
        palette: palette,
        isDark: brightness == Brightness.dark,
      ),
    );
  }

  final asyncAccent = ref.watch(accentColorProvider);
  final accentColor = asyncAccent.whenOrNull(data: (c) => c);
  if (accentColor != null) {
    return ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      contrastLevel: kDefaultContrastLevel,
    );
  }

  return null;
}

/// Light [ColorScheme] with enhanced contrast.
final dynamicLightColorSchemeProvider = Provider<ColorScheme?>((ref) {
  return _resolveDynamicScheme(ref, Brightness.light);
});

/// Dark [ColorScheme] with enhanced contrast.
final dynamicDarkColorSchemeProvider = Provider<ColorScheme?>((ref) {
  return _resolveDynamicScheme(ref, Brightness.dark);
});
