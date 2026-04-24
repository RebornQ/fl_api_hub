/// Repository contract for persisting and reading theme preferences.
library;

import '../../../../core/result/result.dart';
import '../entities/theme_preference.dart';

abstract class ThemeRepository {
  Future<Result<ThemePreference>> getPreference();
  Future<Result<void>> savePreference(ThemePreference preference);
}
