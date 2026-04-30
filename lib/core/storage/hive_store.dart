/// Abstract interface and default implementation for local key-value storage.
///
/// Structured data (account list, API keys, preferences, bookmarks) is
/// stored in Hive boxes as plaintext maps. See each feature's data source
/// for entity-specific serialization.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

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
/// - `tags` — tag entity storage (cross-feature label store)
/// - `check_in_tasks` — check-in task entity storage
/// - `check_in_results` — check-in result entity storage
/// - `check_in_request_logs` — persistent request logs for check-in executions
/// - `scheduler_config` — auto-check-in scheduler configuration
/// - `account_reachability` — cached website reachability per account
/// - `network_proxy` — global network proxy setting (singleton document)
Future<void> initHive() async {
  if (kIsWeb) {
    await Hive.initFlutter();
  } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await Hive.initFlutter('.fl-api-hub/hive');
  } else {
    await Hive.initFlutter('hive');
  }
  await Future.wait([
    Hive.openBox('app_data'),
    Hive.openBox('accounts'),
    Hive.openBox('keys'),
    Hive.openBox('tags'),
    Hive.openBox('check_in_tasks'),
    Hive.openBox('check_in_results'),
    Hive.openBox('check_in_request_logs'),
    Hive.openBox('scheduler_config'),
    Hive.openBox('account_reachability'),
    Hive.openBox('network_proxy'),
  ]);
}

/// Riverpod provider for the application-wide [KeyValueStore].
///
/// Assumes [initHive] has already been called.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return HiveStoreImpl(Hive.box('app_data'));
});
