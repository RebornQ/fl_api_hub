library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/browser_preference.dart';
import '../../domain/repositories/browser_repository.dart';
import '../datasources/browser_local_datasource.dart';

class BrowserRepositoryImpl implements BrowserRepository {
  final BrowserLocalDataSource _local;

  BrowserRepositoryImpl(this._local);

  @override
  Future<Result<BrowserPreference>> getPreference() async {
    try {
      return Success(_local.read());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to read browser preference',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> savePreference(BrowserPreference preference) async {
    try {
      await _local.write(preference);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to save browser preference',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
