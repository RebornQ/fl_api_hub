library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/global_proxy_setting.dart';
import '../../domain/repositories/global_proxy_repository.dart';
import '../datasources/global_proxy_local_datasource.dart';

class GlobalProxyRepositoryImpl implements GlobalProxyRepository {
  final GlobalProxyLocalDataSource _local;

  GlobalProxyRepositoryImpl(this._local);

  @override
  Future<Result<GlobalProxySetting>> getCurrent() async {
    try {
      return Success(_local.read());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to read global proxy setting',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> save(GlobalProxySetting setting) async {
    try {
      await _local.write(setting);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to save global proxy setting',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
