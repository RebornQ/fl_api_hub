/// Riverpod notifier for [SchedulerConfig] state management.
///
/// Loads the config from local storage on build and persists every mutation.
/// UI widgets should watch [schedulerConfigProvider] for reactive updates.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/scheduler_config_local_datasource.dart';
import '../../domain/entities/scheduler_config.dart';

/// Manages the global [SchedulerConfig] state.
///
/// On build, loads the persisted config (or defaults).
/// Every mutation updates state and persists to Hive.
class SchedulerConfigNotifier extends Notifier<SchedulerConfig> {
  @override
  SchedulerConfig build() {
    final ds = ref.read(schedulerConfigLocalDsProvider);
    return ds.load();
  }

  /// Toggles global auto-check-in enabled/disabled.
  Future<void> setEnabled(bool enabled) async {
    await _update(state.copyWith(enabled: enabled));
  }

  /// Updates the daily execution time window.
  Future<void> setTimeWindow(String start, String end) async {
    await _update(state.copyWith(timeWindowStart: start, timeWindowEnd: end));
  }

  /// Updates the retry strategy parameters.
  Future<void> setRetryStrategy({int? intervalMinutes, int? maxRetries}) async {
    await _update(
      state.copyWith(
        retryIntervalMinutes: intervalMinutes,
        maxRetries: maxRetries,
      ),
    );
  }

  /// Generic update: sets state and persists to storage.
  Future<void> _update(SchedulerConfig newConfig) async {
    state = newConfig;
    await ref.read(schedulerConfigLocalDsProvider).save(newConfig);
  }
}
