/// Orchestrates automatic check-in execution based on [SchedulerConfig].
///
/// [CheckInSchedulerService] owns a single periodic timer (1-minute interval)
/// and on each tick evaluates:
/// 1. Is the global config enabled?
/// 2. Is the current time within the configured window?
/// 3. Which enabled tasks are due and haven't been executed today?
/// 4. Execute due tasks via [CheckInNotifier.executeCheckIn].
/// 5. Track retries for failed tasks.
///
/// Lifecycle: [start] when config becomes enabled, [stop] when disabled.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/check_in/domain/entities/check_in_result.dart';
import '../../features/check_in/domain/entities/check_in_task.dart';
import '../../features/check_in/presentation/providers/check_in_providers.dart';

/// Orchestrates automatic check-in execution.
class CheckInSchedulerService {
  final Ref _ref;
  Timer? _tickTimer;

  /// Tracks retry counts per task per day: taskId → retry count.
  final Map<String, int> _retryCounters = {};

  /// Tracks last attempt time per task: taskId → DateTime.
  final Map<String, DateTime> _lastAttemptAt = {};

  /// The date (YYYY-MM-DD) for which retry counters are valid.
  String? _counterDate;

  /// Tick interval — checks every 1 minute.
  static const _tickInterval = Duration(minutes: 1);

  CheckInSchedulerService(this._ref);

  /// Starts the periodic check cycle.
  void start() {
    stop(); // Ensure no duplicate timers.
    _tickTimer = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  /// Stops the periodic check cycle.
  void stop() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Whether the service is currently running.
  bool get isRunning => _tickTimer != null && _tickTimer!.isActive;

  /// Main tick handler — called every ~1 minute.
  Future<void> _onTick() async {
    final config = _ref.read(schedulerConfigProvider);
    if (!config.enabled) return;

    final now = DateTime.now();
    if (!config.isWithinWindow(now)) return;

    _resetCountersIfNeeded(now);

    final dueTasks = _getDueTasks(now);
    if (dueTasks.isEmpty) return;

    await _executeDueTasks(dueTasks);
  }

  /// Returns the list of tasks that should run now.
  List<CheckInTask> _getDueTasks(DateTime now) {
    final tasks = _ref.read(checkInProvider).valueOrNull ?? [];
    return tasks.where((task) {
      if (!task.enabled) return false;
      if (_alreadyExecutedToday(task, now)) return false;
      if (_isInRetryCooldown(task, now)) return false;
      return true;
    }).toList();
  }

  /// Checks whether a task has already been successfully executed today.
  ///
  /// Queries the repository for the latest result and compares dates.
  bool _alreadyExecutedToday(CheckInTask task, DateTime now) {
    final lastRun = task.lastRunAt;
    if (lastRun == null) return false;
    return _sameDay(lastRun, now);
  }

  /// Whether two [DateTime]s are on the same calendar day (local time).
  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Whether a task is in its retry cooldown period.
  bool _isInRetryCooldown(CheckInTask task, DateTime now) {
    final lastAttempt = _lastAttemptAt[task.id];
    if (lastAttempt == null) return false;

    final config = _ref.read(schedulerConfigProvider);
    final cooldownEnd = lastAttempt.add(
      Duration(minutes: config.retryIntervalMinutes),
    );
    return now.isBefore(cooldownEnd);
  }

  /// Executes due tasks with concurrency control (chunk of 5).
  Future<void> _executeDueTasks(List<CheckInTask> tasks) async {
    final notifier = _ref.read(checkInProvider.notifier);

    for (var i = 0; i < tasks.length; i += 5) {
      final chunk = tasks.skip(i).take(5);
      await Future.wait(chunk.map((task) => _executeSingle(notifier, task.id)));
    }
  }

  /// Executes a single task and handles retry tracking.
  Future<void> _executeSingle(dynamic notifier, String taskId) async {
    _lastAttemptAt[taskId] = DateTime.now();

    final result = await notifier.executeCheckIn(taskId);

    if (result != null && result.status == CheckInStatus.failed) {
      _handleRetry(taskId);
    } else if (result != null && result.status == CheckInStatus.success) {
      // Clear retry counter on success.
      _retryCounters.remove(taskId);
      _lastAttemptAt.remove(taskId);
    }
  }

  /// Handles retry logic for a failed task.
  void _handleRetry(String taskId) {
    final config = _ref.read(schedulerConfigProvider);
    final retries = _retryCounters[taskId] ?? 0;

    if (retries < config.maxRetries) {
      _retryCounters[taskId] = retries + 1;
    } else {
      // Max retries exceeded — remove from tracking.
      _retryCounters.remove(taskId);
      _lastAttemptAt.remove(taskId);
    }
  }

  /// Resets daily retry counters when the date changes.
  void _resetCountersIfNeeded(DateTime now) {
    final today = _dateKey(now);
    if (_counterDate != today) {
      _counterDate = today;
      _retryCounters.clear();
      _lastAttemptAt.clear();
    }
  }

  /// Formats a date as YYYY-MM-DD.
  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Disposes all resources.
  void dispose() {
    stop();
    _retryCounters.clear();
    _lastAttemptAt.clear();
  }
}
