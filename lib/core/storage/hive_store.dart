/// Abstract interface and default implementation for local key-value storage.
///
/// Non-sensitive structured data (account list, preferences, bookmarks) is
/// stored in a Hive box. Sensitive data should use [SecureStore] instead.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Interface for a generic key-value store.
abstract class KeyValueStore {
  Future<T?> read<T>(String key);
  Future<void> write<T>(String key, T value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}

/// [KeyValueStore] implementation backed by a Hive [Box].
class HiveStoreImpl implements KeyValueStore {
  final Box _box;

  HiveStoreImpl(this._box);

  @override
  Future<T?> read<T>(String key) async => _box.get(key) as T?;

  @override
  Future<void> write<T>(String key, T value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<bool> containsKey(String key) async => _box.containsKey(key);
}

/// Initializes Hive and opens all application boxes.
///
/// Call this before `runApp()` when local data is needed.
/// Feature boxes are opened per-entity for isolation:
/// - `app_data` — general preferences and simple key-value data
/// - `accounts` — account entity storage
/// - `keys` — API key entity storage
/// - `check_in_tasks` — check-in task entity storage
/// - `check_in_results` — check-in result entity storage
Future<void> initHive() async {
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('app_data'),
    Hive.openBox('accounts'),
    Hive.openBox('keys'),
    Hive.openBox('check_in_tasks'),
    Hive.openBox('check_in_results'),
  ]);
}

/// Riverpod provider for the application-wide [KeyValueStore].
///
/// Assumes [initHive] has already been called.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return HiveStoreImpl(Hive.box('app_data'));
});
