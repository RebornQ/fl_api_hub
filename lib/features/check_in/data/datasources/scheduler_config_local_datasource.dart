/// Local data source for [SchedulerConfig] persistence.
///
/// Stores a single config document in a dedicated Hive box.
/// The key `'global_config'` holds the serialized scheduler settings.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/scheduler_config.dart';
import '../models/scheduler_config_mapper.dart';

/// Box name for scheduler config storage.
const _boxName = 'scheduler_config';

/// Storage key for the global scheduler config.
const _configKey = 'global_config';

/// Local CRUD operations for the global scheduler configuration.
class SchedulerConfigLocalDataSource {
  final Box _box;

  SchedulerConfigLocalDataSource(this._box);

  /// Loads the saved config, or returns defaults if none exists.
  SchedulerConfig load() {
    final raw = _box.get(_configKey);
    if (raw == null) return const SchedulerConfig();
    final map = Map<String, dynamic>.from(raw as Map);
    return SchedulerConfigMapper.fromMap(map);
  }

  /// Persists the given [config].
  Future<void> save(SchedulerConfig config) async {
    await _box.put(_configKey, SchedulerConfigMapper.toMap(config));
  }
}

/// Riverpod provider for [SchedulerConfigLocalDataSource].
final schedulerConfigLocalDsProvider = Provider<SchedulerConfigLocalDataSource>(
  (ref) {
    return SchedulerConfigLocalDataSource(Hive.box(_boxName));
  },
);
