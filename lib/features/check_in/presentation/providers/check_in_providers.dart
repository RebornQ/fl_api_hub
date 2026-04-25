/// Riverpod providers for the Check-in feature.
///
/// Wires [CheckInRepositoryImpl] to its dependencies and exposes:
/// - [checkInProvider] for task list management.
/// - [latestCheckInResultProvider] for the most recent result per task.
/// - [checkInResultsProvider] for the full result history per task.
/// - [latestResultPerAccountProvider] for the newest result per account.
/// - [checkInAccountSummariesProvider] for the master-list view (latest per
///   account, enriched with account names).
/// - [checkInStatsProvider] for aggregate dashboard statistics.
/// - [selectedAccountIdProvider] for wide-screen master-detail selection.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../data/datasources/check_in_local_datasource.dart';
import '../../data/repositories/check_in_repository_impl.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/services/account_check_in_sync_service.dart';
import 'check_in_notifier.dart';

export 'account_check_in_history_notifier.dart';
export 'check_in_notifier.dart';
export 'scheduler_providers.dart';

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

/// Provides the [AccountCheckInSyncService] wired to both repositories.
///
/// Invoked at the top of [CheckInNotifier.executeAll] so tasks always
/// reflect each account's current `autoCheckInEnabled` switch before the
/// batch runs.
final accountCheckInSyncServiceProvider = Provider<AccountCheckInSyncService>((
  ref,
) {
  return AccountCheckInSyncService(
    accountsRepo: ref.watch(accountsRepositoryProvider),
    checkInRepo: ref.watch(checkInRepositoryProvider),
  );
});

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

/// The latest [CheckInResult] for each account that has at least one record,
/// newest first.
///
/// Drives the main check-in list ("one card per account, showing the most
/// recent result"). Accounts with zero records are absent from this list.
final latestResultPerAccountProvider = FutureProvider<List<CheckInResult>>((
  ref,
) async {
  final repo = ref.watch(checkInRepositoryProvider);
  final result = await repo.getLatestResultPerAccount();
  return result.dataOrNull ?? [];
});

/// The latest [CheckInResult] keyed by `accountId` for O(1) lookup.
///
/// Derived from [latestResultPerAccountProvider]. Widgets that need per-account
/// access (e.g. the account card check-in status icon) should watch this with
/// `select()` to avoid unnecessary rebuilds.
final latestResultByAccountProvider = Provider<Map<String, CheckInResult>>((
  ref,
) {
  final results = ref.watch(latestResultPerAccountProvider).valueOrNull ?? [];
  return {for (final r in results) r.accountId: r};
});

/// Computed aggregate statistics for the check-in dashboard.
///
/// Sourced from [latestResultPerAccountProvider] so the numbers match what
/// the user sees in the master list (one row per account).
final checkInStatsProvider = Provider<CheckInDashboardStats>((ref) {
  final tasks = ref.watch(checkInProvider).valueOrNull ?? [];
  final results = ref.watch(latestResultPerAccountProvider).valueOrNull ?? [];
  return CheckInDashboardStats.from(tasks: tasks, results: results);
});

/// Latest-per-account results enriched with account names.
///
/// Drops records whose `accountId` no longer maps to an existing account so
/// orphan entries do not surface in the master list. This is the main list
/// provider consumed by [CheckInPage] — the old `checkInDashboardProvider`
/// is retained for transition but will be removed once all callers migrate.
final checkInAccountSummariesProvider =
    Provider<AsyncValue<List<CheckInResultDisplay>>>((ref) {
      final resultsAsync = ref.watch(latestResultPerAccountProvider);
      final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
      final accountMap = {for (final a in accounts) a.id: a.name};
      final sortOrderMap = {for (final a in accounts) a.id: a.sortOrder};

      return resultsAsync.whenData((results) {
        final summaries = results
            .where((r) => accountMap.containsKey(r.accountId))
            .map(
              (r) => CheckInResultDisplay(
                result: r,
                accountName: accountMap[r.accountId]!,
              ),
            )
            .toList();
        // Sort by the same sortOrder used on the accounts management page.
        summaries.sort(
          (a, b) => (sortOrderMap[a.result.accountId] ?? 0).compareTo(
            sortOrderMap[b.result.accountId] ?? 0,
          ),
        );
        return summaries;
      });
    });

/// Selected account id for the wide-screen master-detail view.
///
/// `null` means "no selection" → the detail pane renders its placeholder.
/// Kept in a global [StateProvider] so it survives `LayoutBuilder` rebuilds
/// when the window resizes. Mobile navigation does not use this — it pushes
/// a dedicated [CheckInAccountDetailPage] instead.
final selectedAccountIdProvider = StateProvider<String?>((_) => null);

/// Results enriched with account names for display in the dashboard.
///
/// Joins each [CheckInResult] with its account name by looking up
/// [accountId] in the accounts list.
@Deprecated(
  'Use checkInAccountSummariesProvider for the per-account master list. '
  'Kept for transition / existing tests; will be removed.',
)
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
        .where(
          (r) =>
              r.status == CheckInStatus.success ||
              r.status == CheckInStatus.alreadyChecked,
        )
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
