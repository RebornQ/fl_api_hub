/// Local data source for theme preferences stored in Hive [app_data] box.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../domain/entities/theme_preference.dart';

class ThemeLocalDataSource {
  static const _keyThemeMode = 'theme_mode';
  static const _keyDynamicColor = 'dynamic_color_enabled';

  final Box _box;

  ThemeLocalDataSource(this._box);

  /// Read the stored [ThemePreference], falling back to defaults.
  ThemePreference read() {
    final modeStr = _box.get(_keyThemeMode) as String?;
    final dynamicEnabled = _box.get(_keyDynamicColor) as bool?;
    return ThemePreference(
      themeMode: AppThemeMode.fromString(modeStr),
      dynamicColorEnabled: dynamicEnabled ?? true,
    );
  }

  /// Persist the given [preference].
  Future<void> write(ThemePreference preference) async {
    await Future.wait([
      _box.put(_keyThemeMode, preference.themeMode.serialize),
      _box.put(_keyDynamicColor, preference.dynamicColorEnabled),
    ]);
  }
}

/// Riverpod provider for [ThemeLocalDataSource].
///
/// Assumes Hive `app_data` box is already opened.
final themeLocalDataSourceProvider = Provider<ThemeLocalDataSource>((ref) {
  return ThemeLocalDataSource(Hive.box('app_data'));
});
