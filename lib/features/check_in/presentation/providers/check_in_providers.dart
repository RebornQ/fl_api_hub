/// Riverpod providers for the Check-in feature.
///
/// Wires [CheckInRepositoryImpl] to its dependencies and exposes:
/// - [checkInProvider] for task list management.
/// - [latestCheckInResultProvider] for the most recent result per task.
/// - [checkInResultsProvider] for the full result history per task.
/// - [allCheckInResultsProvider] for all results across tasks (dashboard).
/// - [checkInStatsProvider] for aggregate dashboard statistics.
/// - [checkInDashboardProvider] for results enriched with account names.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../data/datasources/check_in_local_datasource.dart';
import '../../data/repositories/check_in_repository_impl.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../../domain/repositories/check_in_repository.dart';
import 'check_in_notifier.dart';

export 'check_in_notifier.dart';

// ── Repository & Task providers ────────────────────────────────────

/// Provides the [CheckInRepository] implementation.
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepositoryImpl(ref.watch(checkInLocalDataSourceProvider));
});

/// Manages the list of [CheckInTask] entities.
///
/// UI code should watch this provider to display the task list.
/// Use the notifier methods for CRUD and manual check-in execution.
final checkInProvider =
    AsyncNotifierProvider<CheckInNotifier, List<CheckInTask>>(
      CheckInNotifier.new,
    );

// ── Per-task result providers ───────────────────────────────────────

/// Read-only provider for the latest [CheckInResult] of a task.
///
/// Returns `null` if the task has never been executed.
final latestCheckInResultProvider =
    FutureProvider.family<CheckInResult?, String>((ref, taskId) async {
      final repo = ref.watch(checkInRepositoryProvider);
      final result = await repo.getLatestResult(taskId);
      return result.dataOrNull;
    });

/// Read-only provider for all [CheckInResult]s of a task, newest first.
final checkInResultsProvider =
    FutureProvider.family<List<CheckInResult>, String>((ref, taskId) async {
      final repo = ref.watch(checkInRepositoryProvider);
      final result = await repo.getResultsByTaskId(taskId);
      return result.dataOrNull ?? [];
    });

// ── Dashboard providers ─────────────────────────────────────────────

/// All check-in results across all tasks, newest first.
///
/// Used by the dashboard page to display the results log.
final allCheckInResultsProvider = FutureProvider<List<CheckInResult>>((
  ref,
) async {
  final repo = ref.watch(checkInRepositoryProvider);
  final result = await repo.getAllResults();
  return result.dataOrNull ?? [];
});

/// Computed aggregate statistics for the check-in dashboard.
final checkInStatsProvider = Provider<CheckInDashboardStats>((ref) {
  final tasks = ref.watch(checkInProvider).valueOrNull ?? [];
  final results = ref.watch(allCheckInResultsProvider).valueOrNull ?? [];
  return CheckInDashboardStats.from(tasks: tasks, results: results);
});

/// Results enriched with account names for display in the dashboard.
///
/// Joins each [CheckInResult] with its account name by looking up
/// [accountId] in the accounts list.
final checkInDashboardProvider =
    Provider<AsyncValue<List<CheckInResultDisplay>>>((ref) {
      final resultsAsync = ref.watch(allCheckInResultsProvider);
      final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
      final accountMap = {for (final a in accounts) a.id: a.name};

      return resultsAsync.whenData(
        (results) => results
            .map(
              (r) => CheckInResultDisplay(
                result: r,
                accountName: accountMap[r.accountId] ?? '未知账号',
              ),
            )
            .toList(),
      );
    });

// ── Dashboard model classes ─────────────────────────────────────────

/// Overall status of the last check-in batch.
enum CheckInOverallStatus { allSuccess, partial, allFailed, none }

/// Aggregate statistics for the check-in dashboard summary panel.
class CheckInDashboardStats {
  final int eligible;
  final int executed;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final CheckInOverallStatus overallStatus;

  const CheckInDashboardStats({
    required this.eligible,
    required this.executed,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    this.nextRunAt,
    this.lastRunAt,
    required this.overallStatus,
  });

  /// Computes stats from the current tasks and results.
  factory CheckInDashboardStats.from({
    required List<CheckInTask> tasks,
    required List<CheckInResult> results,
  }) {
    final enabledTasks = tasks.where((t) => t.enabled).length;

    // Distinct task IDs that have at least one result.
    final tasksWithResults = results.map((r) => r.taskId).toSet().length;

    final successCount = results
        .where((r) => r.status == CheckInStatus.success)
        .length;
    final failedCount = results
        .where((r) => r.status == CheckInStatus.failed)
        .length;
    final skippedCount = results
        .where((r) => r.status == CheckInStatus.skipped)
        .length;

    // Earliest nextRunAt among enabled tasks.
    final nextRuns =
        tasks
            .where((t) => t.enabled && t.nextRunAt != null)
            .map((t) => t.nextRunAt!)
            .toList()
          ..sort();
    final nextRunAt = nextRuns.isNotEmpty ? nextRuns.first : null;

    // Latest lastRunAt across all tasks.
    final lastRuns =
        tasks
            .where((t) => t.lastRunAt != null)
            .map((t) => t.lastRunAt!)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final lastRunAt = lastRuns.isNotEmpty ? lastRuns.first : null;

    // Determine overall status from the latest batch of results.
    final overallStatus = _computeOverallStatus(
      successCount: successCount,
      failedCount: failedCount,
    );

    return CheckInDashboardStats(
      eligible: enabledTasks,
      executed: tasksWithResults,
      successCount: successCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
      nextRunAt: nextRunAt,
      lastRunAt: lastRunAt,
      overallStatus: overallStatus,
    );
  }

  static CheckInOverallStatus _computeOverallStatus({
    required int successCount,
    required int failedCount,
  }) {
    if (successCount == 0 && failedCount == 0) {
      return CheckInOverallStatus.none;
    } else if (failedCount > 0 && successCount > 0) {
      return CheckInOverallStatus.partial;
    } else if (failedCount > 0) {
      return CheckInOverallStatus.allFailed;
    } else {
      return CheckInOverallStatus.allSuccess;
    }
  }
}

/// Display model pairing a [CheckInResult] with its account name.
///
/// Used by the dashboard to avoid repeated account lookups.
class CheckInResultDisplay {
  final CheckInResult result;
  final String accountName;

  const CheckInResultDisplay({required this.result, required this.accountName});
}
