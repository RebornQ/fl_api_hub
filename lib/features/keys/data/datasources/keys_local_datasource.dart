/// Local data source for [ApiKey] entities using Hive.
///
/// API key data (including secret key value) is stored as a single map in
/// the Hive `keys` box. See [ApiKeyMapper] for serialization details.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/api_key.dart';
import '../models/api_key_mapper.dart';

/// Box name for API key entity storage.
const _boxName = 'keys';

/// Local CRUD operations for [ApiKey] entities.
class KeysLocalDataSource {
  final Box _box;

  KeysLocalDataSource(this._box);

  /// Returns all API keys for a specific [accountId].
  List<ApiKey> getByAccountId(String accountId) {
    return _box.values
        .map((raw) => _parseKey(raw))
        .where((key) => key.accountId == accountId)
        .toList();
  }

  /// Returns all stored API keys.
  List<ApiKey> getAll() {
    return _box.values.map((raw) => _parseKey(raw)).toList();
  }

  /// Returns a single API key by [id], or `null` if not found.
  ApiKey? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return _parseKey(raw);
  }

  /// Persists an [apiKey] to the local box.
  Future<void> save(ApiKey apiKey) async {
    await _box.put(apiKey.id, ApiKeyMapper.toMap(apiKey));
  }

  /// Deletes an API key by [id].
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Deletes all API keys belonging to a specific [accountId].
  Future<void> deleteByAccountId(String accountId) async {
    final keys = getByAccountId(accountId);
    for (final key in keys) {
      await delete(key.id);
    }
  }

  /// Safely converts a raw Hive value into an [ApiKey].
  ///
  /// Hive stores maps as `_Map<dynamic, dynamic>`, which cannot be cast
  /// directly to `Map<String, dynamic>`. We convert via
  /// `Map<String, dynamic>.from()` before passing to the mapper.
  static ApiKey _parseKey(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return ApiKeyMapper.fromMap(map);
  }
}

/// Riverpod provider for [KeysLocalDataSource].
final keysLocalDataSourceProvider = Provider<KeysLocalDataSource>((ref) {
  return KeysLocalDataSource(Hive.box(_boxName));
});
