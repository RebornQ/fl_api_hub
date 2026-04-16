/// Abstract scheduler interface for periodic background tasks.
///
/// Platform implementations (WorkManager, BGTaskScheduler, etc.) will be
/// plugged in later. For now this defines the contract that the check-in
/// and balance-snapshot features will depend on.
library;

/// Callback signature for foreground task execution.
///
/// [id] is the unique identifier passed to [AppScheduler.schedulePeriodic].
typedef ScheduledTaskCallback = Future<void> Function(String id);

/// Schedules and manages periodic background tasks.
abstract class AppScheduler {
  /// Schedules a repeating task.
  ///
  /// [id] is a unique identifier for this scheduled task.
  /// [taskName] identifies what to run (e.g. 'check_in', 'balance_snapshot').
  /// [interval] is the minimum time between executions.
  /// [onTick] is an optional callback invoked on each tick (foreground mode).
  Future<void> schedulePeriodic({
    required String id,
    required String taskName,
    required Duration interval,
    ScheduledTaskCallback? onTick,
  });

  /// Cancels a previously scheduled task by [id].
  Future<void> cancel(String id);

  /// Returns `true` if a task with [id] is currently scheduled.
  Future<bool> isScheduled(String id);
}
