library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/theme_preference.dart';
import '../../domain/repositories/theme_repository.dart';
import '../datasources/theme_local_datasource.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  final ThemeLocalDataSource _local;

  ThemeRepositoryImpl(this._local);

  @override
  Future<Result<ThemePreference>> getPreference() async {
    try {
      return Success(_local.read());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to read theme preference',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> savePreference(ThemePreference preference) async {
    try {
      await _local.write(preference);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to save theme preference',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
