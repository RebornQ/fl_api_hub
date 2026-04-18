/// Concrete implementation of [CheckInRepository].
///
/// Delegates all operations to [CheckInLocalDataSource]. Tasks and results
/// are stored in separate Hive boxes.
library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../datasources/check_in_local_datasource.dart';

/// Local-only implementation of [CheckInRepository].
class CheckInRepositoryImpl implements CheckInRepository {
  final CheckInLocalDataSource _local;

  CheckInRepositoryImpl(this._local);

  // ── Task operations ──────────────────────────────────────────────

  @override
  Future<Result<List<CheckInTask>>> getAllTasks() async {
    try {
      return Success(_local.getAllTasks());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load check-in tasks: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<CheckInTask>>> getTasksByAccountId(
    String accountId,
  ) async {
    try {
      return Success(_local.getTasksByAccountId(accountId));
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load tasks for account: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<CheckInTask>> getTaskById(String id) async {
    try {
      final task = _local.getTaskById(id);
      if (task == null) {
        return const Failure(
          StorageException(message: 'Check-in task not found'),
        );
      }
      return Success(task);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load check-in task: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<CheckInTask>> saveTask(CheckInTask task) async {
    try {
      await _local.saveTask(task);
      return Success(task);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to save check-in task: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteTask(String id) async {
    try {
      await _local.deleteTask(id);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to delete check-in task: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  // ── Result operations ────────────────────────────────────────────

  @override
  Future<Result<CheckInResult?>> getLatestResult(String taskId) async {
    try {
      final result = _local.getLatestResult(taskId);
      return Success(result);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load latest result: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<CheckInResult>> saveResult(CheckInResult result) async {
    try {
      await _local.saveResult(result);
      return Success(result);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to save check-in result: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<CheckInResult>>> getResultsByTaskId(String taskId) async {
    try {
      return Success(_local.getResultsByTaskId(taskId));
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load check-in results: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<CheckInResult>>> getAllResults() async {
    try {
      return Success(_local.getAllResults());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load all check-in results: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
