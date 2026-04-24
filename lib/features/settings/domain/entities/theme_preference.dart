/// User preference for the application's visual appearance.
library;

/// Appearance mode selected by the user.
enum AppThemeMode {
  /// Follow the platform's brightness setting.
  system,

  /// Always use light brightness.
  light,

  /// Always use dark brightness.
  dark;

  /// Parse a stored string value back to [AppThemeMode].
  ///
  /// Returns [system] for unknown or null values.
  static AppThemeMode fromString(String? value) => switch (value) {
    'light' => light,
    'dark' => dark,
    'system' => system,
    _ => system,
  };

  /// Serialise to a string suitable for Hive storage.
  String get serialize => name;
}

/// Immutable snapshot of appearance preferences.
class ThemePreference {
  final AppThemeMode themeMode;
  final bool dynamicColorEnabled;

  const ThemePreference({
    this.themeMode = AppThemeMode.system,
    this.dynamicColorEnabled = true,
  });

  ThemePreference copyWith({
    AppThemeMode? themeMode,
    bool? dynamicColorEnabled,
  }) => ThemePreference(
    themeMode: themeMode ?? this.themeMode,
    dynamicColorEnabled: dynamicColorEnabled ?? this.dynamicColorEnabled,
  );
}
