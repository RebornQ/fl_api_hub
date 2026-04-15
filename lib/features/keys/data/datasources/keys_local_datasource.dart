/// Local data source for [ApiKey] entities using Hive + SecureStore.
///
/// API key metadata is stored in a Hive box, while the actual secret key
/// values are kept in encrypted storage via [SecureStore].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/api_key.dart';
import '../models/api_key_mapper.dart';

/// Box name for API key entity storage.
const _boxName = 'keys';

/// SecureStore key prefix for API key secret values.
const _keyValuePrefix = 'api_key_value_';

/// Local CRUD operations for [ApiKey] entities.
class KeysLocalDataSource {
  final Box _box;
  final SecureStore _secureStore;

  KeysLocalDataSource(this._box, this._secureStore);

  /// Returns all API keys for a specific [accountId].
  List<ApiKey> getByAccountId(String accountId) {
    return _box.values
        .cast<Map<String, dynamic>>()
        .where((map) => map['accountId'] == accountId)
        .map(ApiKeyMapper.fromMap)
        .toList();
  }

  /// Returns all stored API keys.
  List<ApiKey> getAll() {
    return _box.values
        .cast<Map<String, dynamic>>()
        .map(ApiKeyMapper.fromMap)
        .toList();
  }

  /// Returns a single API key by [id], or `null` if not found.
  ApiKey? getById(String id) {
    final map = _box.get(id) as Map<String, dynamic>?;
    if (map == null) return null;
    return ApiKeyMapper.fromMap(map);
  }

  /// Persists an [apiKey] to the local box.
  ///
  /// If [keyValue] (the actual secret) is provided, it is stored securely.
  Future<void> save(ApiKey apiKey, {String? keyValue}) async {
    await _box.put(apiKey.id, ApiKeyMapper.toMap(apiKey));
    if (keyValue != null) {
      await _secureStore.write('$_keyValuePrefix${apiKey.id}', keyValue);
    }
  }

  /// Retrieves the stored secret key value for [keyId].
  ///
  /// Returns `null` if no value has been stored.
  Future<String?> getKeyValue(String keyId) {
    return _secureStore.read('$_keyValuePrefix$keyId');
  }

  /// Deletes an API key and its associated secret value.
  Future<void> delete(String id) async {
    await _box.delete(id);
    await _secureStore.delete('$_keyValuePrefix$id');
  }

  /// Deletes all API keys belonging to a specific [accountId].
  Future<void> deleteByAccountId(String accountId) async {
    final keys = getByAccountId(accountId);
    for (final key in keys) {
      await delete(key.id);
    }
  }
}

/// Riverpod provider for [KeysLocalDataSource].
final keysLocalDataSourceProvider = Provider<KeysLocalDataSource>((ref) {
  return KeysLocalDataSource(
    Hive.box(_boxName),
    ref.watch(secureStoreProvider),
  );
});
