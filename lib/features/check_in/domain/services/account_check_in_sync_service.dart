/// Reconciles [CheckInTask] entries with each [Account]'s check-in config.
///
/// This service is invoked at the top of the FAB "立即执行" flow so that the
/// task list the scheduler sees is always in sync with the account-level
/// `autoCheckInEnabled` switch. The reconciliation is **idempotent** and
/// **non-destructive**:
///
///   - account.autoCheckInEnabled=true  + no task        → create an enabled
///     task with [defaultScheduleTime].
///   - account.autoCheckInEnabled=true  + existing task  → force the task's
///     `enabled` flag to `true` (scheduleTime, lastRunAt, history preserved).
///   - account.autoCheckInEnabled=false + existing task  → force the task's
///     `enabled` flag to `false`. The task row and its historical
///     [CheckInResult]s stay intact so the user can still browse past
///     results and re-enable without losing context.
///   - account.autoCheckInEnabled=false + no task        → no-op.
///
/// The service does not itself dispatch check-ins — the notifier calls
/// [sync] first and then runs its usual executeAll flow.
library;

import 'package:uuid/uuid.dart';

import '../../../../core/result/result.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../entities/check_in_task.dart';
import '../repositories/check_in_repository.dart';

/// Aggregate counters returned from [AccountCheckInSyncService.sync].
class SyncSummary {
  /// Brand-new tasks created during this sync run.
  final int created;

  /// Existing tasks that were (re-)enabled during this sync run.
  ///
  /// Counts tasks whose `enabled` transitioned from `false` → `true` OR
  /// tasks that were already enabled but belong to an auto-check-in-enabled
  /// account. Use [enabledTransitions] if you need only the transitions.
  final int enabledCount;

  /// Existing tasks that had `enabled` forced to `false` during this run.
  final int disabledCount;

  const SyncSummary({
    required this.created,
    required this.enabledCount,
    required this.disabledCount,
  });

  /// Total number of task rows that were written (created + toggled).
  int get writeCount => created + disabledCount + enabledTransitions;

  /// Subset of [enabledCount] that represents true false→true transitions.
  ///
  /// Newly created tasks are [created] and NOT double-counted here.
  int get enabledTransitions =>
      enabledCount > created ? enabledCount - created : enabledCount;

  @override
  String toString() =>
      'SyncSummary(created: $created, enabled: $enabledCount, '
      'disabled: $disabledCount)';
}

/// Orchestrates the account → CheckInTask reconciliation.
class AccountCheckInSyncService {
  AccountCheckInSyncService({
    required AccountsRepository accountsRepo,
    required CheckInRepository checkInRepo,
    this.defaultScheduleTime = '09:00',
    DateTime Function()? now,
    String Function()? newId,
  }) : _accountsRepo = accountsRepo,
       _checkInRepo = checkInRepo,
       _now = now ?? DateTime.now,
       _newId = newId ?? _defaultIdFactory;

  final AccountsRepository _accountsRepo;
  final CheckInRepository _checkInRepo;

  /// Default `HH:mm` timestamp used when a brand-new task is created.
  ///
  /// Only applied to auto-created tasks. Existing tasks retain their own
  /// `scheduleTime` — this service never rewrites schedule windows.
  final String defaultScheduleTime;

  final DateTime Function() _now;
  final String Function() _newId;

  /// Reconciles tasks against the current account list.
  ///
  /// Returns a [Failure] wrapping the underlying repository error when the
  /// account read fails. Individual task writes that fail are skipped and
  /// do not abort the whole sync — they simply won't contribute to the
  /// returned counters.
  Future<Result<SyncSummary>> sync() async {
    final accountsResult = await _accountsRepo.getAll();
    if (accountsResult is Failure<List<Account>>) {
      return Failure<SyncSummary>(accountsResult.exception);
    }
    final accounts = (accountsResult as Success<List<Account>>).data;

    var created = 0;
    var enabledCount = 0;
    var disabledCount = 0;

    for (final account in accounts) {
      final tasksResult = await _checkInRepo.getTasksByAccountId(account.id);
      if (tasksResult is Failure<List<CheckInTask>>) {
        continue;
      }
      final existing = (tasksResult as Success<List<CheckInTask>>).data;

      if (account.checkIn.autoCheckInEnabled) {
        if (existing.isEmpty) {
          // Create a fresh enabled task for this account.
          final now = _now();
          final task = CheckInTask(
            id: _newId(),
            accountId: account.id,
            enabled: true,
            scheduleTime: defaultScheduleTime,
            createdAt: now,
            updatedAt: now,
          );
          final write = await _checkInRepo.saveTask(task);
          if (write is Success<CheckInTask>) {
            created++;
          }
        } else {
          // Force every associated task to enabled=true. Preserve every
          // other field (scheduleTime, lastRunAt, nextRunAt, history).
          for (final task in existing) {
            if (!task.enabled) {
              final updated = task.copyWith(enabled: true, updatedAt: _now());
              final write = await _checkInRepo.saveTask(updated);
              if (write is Success<CheckInTask>) {
                enabledCount++;
              }
            } else {
              enabledCount++;
            }
          }
        }
      } else {
        // Account opted out: keep any existing task but force enabled=false.
        for (final task in existing) {
          if (task.enabled) {
            final updated = task.copyWith(enabled: false, updatedAt: _now());
            final write = await _checkInRepo.saveTask(updated);
            if (write is Success<CheckInTask>) {
              disabledCount++;
            }
          }
        }
      }
    }

    return Success<SyncSummary>(
      SyncSummary(
        created: created,
        enabledCount: enabledCount,
        disabledCount: disabledCount,
      ),
    );
  }

  static const _uuid = Uuid();
  static String _defaultIdFactory() => _uuid.v4();
}
