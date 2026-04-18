/// Concrete implementation of [KeysRepository] backed by local storage.
///
/// Delegates all operations to [KeysLocalDataSource]. API key data
/// (including secret value) is persisted as a single Hive entry.
library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/api_key.dart';
import '../../domain/repositories/keys_repository.dart';
import '../datasources/keys_local_datasource.dart';

/// Local-only implementation of [KeysRepository].
class KeysRepositoryImpl implements KeysRepository {
  final KeysLocalDataSource _local;

  KeysRepositoryImpl(this._local);

  @override
  Future<Result<List<ApiKey>>> getByAccountId(String accountId) async {
    try {
      return Success(_local.getByAccountId(accountId));
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load API keys: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<ApiKey>> getById(String id) async {
    try {
      final key = _local.getById(id);
      if (key == null) {
        return const Failure(StorageException(message: 'API key not found'));
      }
      return Success(key);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load API key: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<ApiKey>> create(ApiKey apiKey) async {
    try {
      await _local.save(apiKey);
      return Success(apiKey);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to create API key: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<ApiKey>> update(ApiKey apiKey) async {
    try {
      await _local.save(apiKey);
      return Success(apiKey);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to update API key: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _local.delete(id);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to delete API key: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
