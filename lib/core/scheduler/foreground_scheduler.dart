/// Foreground Timer-based implementation of [AppScheduler].
///
/// Suitable for tasks that only need to run while the app is in the
/// foreground. Each scheduled task gets its own [Timer.periodic] that
/// invokes the registered callback on each tick.
///
/// For platform-level background scheduling, use WorkManager (Android) or
/// BGTaskScheduler (iOS) implementations instead.
library;

import 'dart:async';

import 'scheduler.dart';

/// Foreground Timer-based implementation of [AppScheduler].
class ForegroundScheduler implements AppScheduler {
  final Map<String, Timer> _timers = {};
  final Map<String, _ScheduledEntry> _entries = {};

  @override
  Future<void> schedulePeriodic({
    required String id,
    required String taskName,
    required Duration interval,
    ScheduledTaskCallback? onTick,
  }) async {
    await cancel(id);

    final entry = _ScheduledEntry(
      id: id,
      taskName: taskName,
      interval: interval,
      callback: onTick,
    );
    _entries[id] = entry;

    if (onTick != null) {
      _timers[id] = Timer.periodic(interval, (_) async {
        await onTick(id);
      });
    }
  }

  @override
  Future<void> cancel(String id) async {
    _timers[id]?.cancel();
    _timers.remove(id);
    _entries.remove(id);
  }

  @override
  Future<bool> isScheduled(String id) async {
    return _timers.containsKey(id) && _timers[id]!.isActive;
  }

  /// Cancels all active timers.
  ///
  /// Call when the app goes to background (paused/inactive).
  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Re-schedules all previously registered tasks.
  ///
  /// Call when the app returns to foreground (resumed).
  Future<void> rescheduleAll() async {
    for (final entry in _entries.values) {
      if (!_timers.containsKey(entry.id) && entry.callback != null) {
        _timers[entry.id] = Timer.periodic(entry.interval, (_) async {
          await entry.callback!(entry.id);
        });
      }
    }
  }

  /// Disposes all resources. Call on app shutdown.
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _entries.clear();
  }
}

/// Internal representation of a scheduled task entry.
class _ScheduledEntry {
  final String id;
  final String taskName;
  final Duration interval;
  final ScheduledTaskCallback? callback;

  const _ScheduledEntry({
    required this.id,
    required this.taskName,
    required this.interval,
    this.callback,
  });
}
