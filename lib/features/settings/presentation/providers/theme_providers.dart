library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Whether the current platform supports dynamic color (Monet).
///
/// Set by [DynamicColorBuilder] in [App]; defaults to `false` until
/// the first callback fires.
final dynamicColorAvailableProvider = StateProvider<bool>((ref) => false);
