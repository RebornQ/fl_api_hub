/// Repository contract for check-in task and result operations.
///
/// This interface defines the domain-level API for managing check-in tasks
/// and their execution results. Implementations may combine local storage
/// with remote API calls for actual check-in execution.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/check_in_result.dart';
import '../entities/check_in_task.dart';

/// Abstract repository for check-in task and result operations.
abstract class CheckInRepository {
  // ── Task operations ──────────────────────────────────────────────

  /// Returns all check-in tasks.
  Future<Result<List<CheckInTask>>> getAllTasks();

  /// Returns tasks for a specific [accountId].
  Future<Result<List<CheckInTask>>> getTasksByAccountId(String accountId);

  /// Returns a single task by [id].
  Future<Result<CheckInTask>> getTaskById(String id);

  /// Creates or updates a check-in task.
  Future<Result<CheckInTask>> saveTask(CheckInTask task);

  /// Deletes a task and its associated results.
  Future<Result<void>> deleteTask(String id);

  // ── Result operations ────────────────────────────────────────────

  /// Returns the most recent result for [taskId].
  Future<Result<CheckInResult?>> getLatestResult(String taskId);

  /// Saves a check-in execution result.
  Future<Result<CheckInResult>> saveResult(CheckInResult result);

  /// Returns all results for [taskId], newest first.
  Future<Result<List<CheckInResult>>> getResultsByTaskId(String taskId);

  /// Returns all check-in results across all tasks, newest first.
  Future<Result<List<CheckInResult>>> getAllResults();

  /// Returns the latest result per distinct `accountId`, newest first.
  ///
  /// Used by the main check-in list to show one row per account. Accounts
  /// with zero recorded results do not appear in the output.
  Future<Result<List<CheckInResult>>> getLatestResultPerAccount();

  /// Returns a page of results for [accountId], newest first.
  ///
  /// Uses `skip(offset).take(limit)` over the account's full history.
  /// Per-account retention is capped at 50, so pagination cost is bounded.
  Future<Result<List<CheckInResult>>> getResultsByAccountIdPaged(
    String accountId, {
    required int limit,
    required int offset,
  });

  /// Returns the total result count for [accountId].
  Future<Result<int>> countResultsByAccountId(String accountId);

  /// Deletes every result for [accountId]. Returns the count removed.
  Future<Result<int>> deleteAllResultsByAccountId(String accountId);

  /// One-shot migration: trims every account's results down to [keep] entries
  /// by deleting the oldest records first. Intended for app startup.
  Future<Result<void>> migrateResultsToCap({int keep = 50});
}
