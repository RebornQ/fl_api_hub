library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/theme_preference.dart';
import '../../domain/repositories/theme_repository.dart';
import 'theme_providers.dart';

class ThemeNotifier extends AsyncNotifier<ThemePreference> {
  @override
  Future<ThemePreference> build() async {
    final result = await _repo.getPreference();
    return switch (result) {
      Success(:final data) => data,
      Failure() => const ThemePreference(),
    };
  }

  ThemeRepository get _repo => ref.read(themeRepositoryProvider);

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = state.valueOrNull ?? const ThemePreference();
    final updated = current.copyWith(themeMode: mode);
    state = AsyncData(updated);
    await _repo.savePreference(updated);
  }

  Future<void> setDynamicColorEnabled(bool enabled) async {
    final current = state.valueOrNull ?? const ThemePreference();
    final updated = current.copyWith(dynamicColorEnabled: enabled);
    state = AsyncData(updated);
    await _repo.savePreference(updated);
  }
}
