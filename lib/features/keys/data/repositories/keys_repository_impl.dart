/// Remote-first implementation of [KeysRepository].
///
/// Write operations (create, update, delete) call the remote API first,
/// then update the local cache on success. Read operations (getByAccountId)
/// fetch from remote, update local cache, and fall back to local cache on
/// network failure.
library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_request.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/api_key.dart';
import '../../domain/repositories/keys_repository.dart';
import '../datasources/keys_local_datasource.dart';
import '../datasources/keys_remote_datasource.dart';
import '../models/api_key_api_mapper.dart';

/// [KeysRepository] backed by remote API with local Hive cache.
class KeysRepositoryImpl implements KeysRepository {
  final KeysRemoteDataSource? _remote;
  final ApiRequest? _request;
  final KeysLocalDataSource _local;

  const KeysRepositoryImpl._({
    KeysRemoteDataSource? remote,
    ApiRequest? request,
    required KeysLocalDataSource local,
  }) : _remote = remote,
       _request = request,
       _local = local;

  /// Creates a remote-enabled repository.
  factory KeysRepositoryImpl({
    required KeysRemoteDataSource remote,
    required ApiRequest request,
    required KeysLocalDataSource local,
  }) => KeysRepositoryImpl._(remote: remote, request: request, local: local);

  /// Creates a local-only repository (no remote connectivity).
  factory KeysRepositoryImpl.localOnly(KeysLocalDataSource local) =>
      KeysRepositoryImpl._(local: local);

  bool get _canRemote => _remote != null && _request != null;

  @override
  Future<Result<List<ApiKey>>> getByAccountId(String accountId) async {
    // Try remote first, then fallback to local cache.
    if (_canRemote) {
      final result = await _remote!.listTokens(_request!);
      switch (result) {
        case Success(:final data):
          final keys = ApiKeyApiMapper.toEntityList(
            data.tokens,
            accountId: accountId,
          );
          await _replaceLocalCache(accountId, keys);
          return Success(keys);
        case Failure():
          // Remote failed — fall through to local cache.
          break;
      }
    }
    return _localGetByAccountId(accountId);
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
    if (_canRemote) {
      final result = await _remote!.createToken(
        _request!,
        name: apiKey.name,
        quota: apiKey.quota,
        expiresAt: apiKey.expiresAt,
        unlimitedQuota: apiKey.quota == null,
        group: apiKey.group,
      );
      switch (result) {
        case Success(:final data):
          final created = ApiKeyApiMapper.toEntity(
            data,
            accountId: apiKey.accountId,
          ).copyWith(keyValue: data.key);
          await _local.save(created);
          return Success(created);
        case Failure(:final exception):
          return Failure(exception);
      }
    }
    // Local-only fallback.
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
    if (_canRemote) {
      final result = await _remote!.updateToken(
        _request!,
        tokenId: apiKey.id,
        name: apiKey.name,
        quota: apiKey.quota,
        expiresAt: apiKey.expiresAt,
        group: apiKey.group,
      );
      switch (result) {
        case Success():
          await _local.save(apiKey);
          return Success(apiKey);
        case Failure(:final exception):
          return Failure(exception);
      }
    }
    // Local-only fallback.
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
    if (_canRemote) {
      final result = await _remote!.deleteToken(_request!, tokenId: id);
      switch (result) {
        case Success():
          await _local.delete(id);
          return const Success(null);
        case Failure(:final exception):
          return Failure(exception);
      }
    }
    // Local-only fallback.
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

  @override
  Future<Result<ApiKey>> resolveKey(String keyId, String accountId) async {
    if (!_canRemote) {
      return const Failure(
        NetworkException(message: 'No remote connection available'),
      );
    }
    final result = await _remote!.resolveTokenKey(_request!, tokenId: keyId);
    switch (result) {
      case Success(:final data):
        final existing = _local.getById(keyId);
        final updated =
            (existing ?? ApiKeyApiMapper.toEntity(data, accountId: accountId))
                .copyWith(keyValue: data.key);
        await _local.save(updated);
        return Success(updated);
      case Failure(:final exception):
        return Failure(exception);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Replaces all locally cached keys for [accountId] with [keys].
  Future<void> _replaceLocalCache(String accountId, List<ApiKey> keys) async {
    await _local.deleteByAccountId(accountId);
    for (final key in keys) {
      await _local.save(key);
    }
  }

  /// Reads keys from local cache only.
  Result<List<ApiKey>> _localGetByAccountId(String accountId) {
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
}
