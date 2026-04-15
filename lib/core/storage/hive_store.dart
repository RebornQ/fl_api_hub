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

/// Initializes Hive and opens the default box.
///
/// Call this before `runApp()` when local data is needed.
/// TypeAdapters will be registered in later batches as domain models are
/// defined.
Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox('app_data');
}

/// Riverpod provider for the application-wide [KeyValueStore].
///
/// Assumes [initHive] has already been called.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return HiveStoreImpl(Hive.box('app_data'));
});
