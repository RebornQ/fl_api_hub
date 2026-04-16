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
}
