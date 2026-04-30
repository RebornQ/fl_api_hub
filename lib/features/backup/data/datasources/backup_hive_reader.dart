/// Reads all data from the 8 backed-up Hive boxes and writes data back.
///
/// Operates on raw `Map<String, dynamic>` values — the same format that
/// existing mappers' `toMap()` produces. This avoids depending on typed
/// entity classes and provides forward compatibility.
library;

import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/backup_data.dart';

/// Names of the 8 Hive boxes included in a backup.
const _boxNames = [
  'accounts',
  'keys',
  'tags',
  'check_in_tasks',
  'check_in_results',
  'scheduler_config',
  'app_data',
  'network_proxy',
];

/// Keys in `app_data` that are excluded from backup (device-specific settings).
const _excludedAppDataKeys = {'backup_password', 'backup_encrypted'};

/// Reads and writes backup data to/from Hive boxes.
class BackupHiveReader {
  /// Reads all 8 boxes and returns a [BackupData].
  BackupData readAll() {
    return BackupData(
      accounts: _readBox('accounts'),
      keys: _readBox('keys'),
      tags: _readBox('tags'),
      checkInTasks: _readBox('check_in_tasks'),
      checkInResults: _readBox('check_in_results'),
      schedulerConfig: _readSingleton('scheduler_config'),
      appData: _readAppData(),
      globalProxy: _readSingleton('network_proxy'),
    );
  }

  /// Clears all 8 boxes then writes [data] (replace strategy).
  Future<void> writeAll(BackupData data) async {
    await clearAll();
    await _writeData(data);
  }

  /// Writes [data] into the 8 boxes without clearing first (merge strategy).
  Future<void> writeData(BackupData data) async {
    await _writeData(data);
  }

  /// Clears all data in the 8 boxes.
  Future<void> clearAll() async {
    for (final name in _boxNames) {
      await Hive.box(name).clear();
    }
  }

  // -- Private helpers ------------------------------------------------------

  List<Map<String, dynamic>> _readBox(String boxName) {
    final box = Hive.box(boxName);
    return box.values
        .map((dynamic raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
  }

  Map<String, dynamic> _readSingleton(String boxName) {
    final box = Hive.box(boxName);
    final map = <String, dynamic>{};
    for (final key in box.keys) {
      map[key.toString()] = box.get(key);
    }
    return map;
  }

  Map<String, dynamic> _readAppData() {
    final box = Hive.box('app_data');
    final map = <String, dynamic>{};
    for (final key in box.keys) {
      if (!_excludedAppDataKeys.contains(key.toString())) {
        map[key.toString()] = box.get(key);
      }
    }
    return map;
  }

  Future<void> _writeData(BackupData data) async {
    // Write list-based boxes.
    await _writeBox('accounts', data.accounts);
    await _writeBox('keys', data.keys);
    await _writeBox('tags', data.tags);
    await _writeBox('check_in_tasks', data.checkInTasks);
    await _writeBox('check_in_results', data.checkInResults);

    // Write singleton boxes.
    await _writeSingleton('scheduler_config', data.schedulerConfig);
    await _writeSingleton('app_data', data.appData);
    await _writeSingleton('network_proxy', data.globalProxy);
  }

  Future<void> _writeBox(
    String boxName,
    List<Map<String, dynamic>> entries,
  ) async {
    final box = Hive.box(boxName);
    final futures = <Future>[];
    for (final map in entries) {
      final id = map['id'];
      if (id != null) {
        futures.add(box.put(id, map));
      }
    }
    await Future.wait(futures);
  }

  Future<void> _writeSingleton(
    String boxName,
    Map<String, dynamic> data,
  ) async {
    final box = Hive.box(boxName);
    final futures = <Future>[];
    for (final entry in data.entries) {
      futures.add(box.put(entry.key, entry.value));
    }
    await Future.wait(futures);
  }
}
