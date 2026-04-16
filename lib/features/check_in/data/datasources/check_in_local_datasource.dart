/// Local data source for [CheckInTask] and [CheckInResult] entities.
///
/// Tasks and results are stored in separate Hive boxes. Tasks hold the
/// scheduling configuration; results capture individual execution outcomes.
/// No sensitive data is involved, so SecureStore is not needed here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../models/check_in_mapper.dart';

/// Box name for check-in task storage.
const _taskBoxName = 'check_in_tasks';

/// Box name for check-in result storage.
const _resultBoxName = 'check_in_results';

/// Local CRUD operations for check-in tasks and results.
class CheckInLocalDataSource {
  final Box _taskBox;
  final Box _resultBox;

  CheckInLocalDataSource(this._taskBox, this._resultBox);

  // ── Task operations ──────────────────────────────────────────────

  /// Returns all stored check-in tasks.
  List<CheckInTask> getAllTasks() {
    return _taskBox.values
        .cast<Map<String, dynamic>>()
        .map(CheckInTaskMapper.fromMap)
        .toList();
  }

  /// Returns tasks filtered by [accountId].
  List<CheckInTask> getTasksByAccountId(String accountId) {
    return _taskBox.values
        .cast<Map<String, dynamic>>()
        .where((map) => map['accountId'] == accountId)
        .map(CheckInTaskMapper.fromMap)
        .toList();
  }

  /// Returns a single task by [id], or `null` if not found.
  CheckInTask? getTaskById(String id) {
    final map = _taskBox.get(id) as Map<String, dynamic>?;
    if (map == null) return null;
    return CheckInTaskMapper.fromMap(map);
  }

  /// Persists a [task] to the local box.
  Future<void> saveTask(CheckInTask task) async {
    await _taskBox.put(task.id, CheckInTaskMapper.toMap(task));
  }

  /// Deletes a task and all its associated results.
  Future<void> deleteTask(String id) async {
    await _taskBox.delete(id);
    await _deleteResultsByTaskId(id);
  }

  /// Deletes all tasks and results belonging to [accountId].
  Future<void> deleteTasksByAccountId(String accountId) async {
    final tasks = getTasksByAccountId(accountId);
    for (final task in tasks) {
      await deleteTask(task.id);
    }
  }

  // ── Result operations ────────────────────────────────────────────

  /// Persists a [result] to the local box.
  Future<void> saveResult(CheckInResult result) async {
    await _resultBox.put(result.id, CheckInResultMapper.toMap(result));
  }

  /// Returns the most recent result for a given [taskId].
  ///
  /// Returns `null` if no results exist for the task.
  CheckInResult? getLatestResult(String taskId) {
    final results = _resultBox.values
        .cast<Map<String, dynamic>>()
        .where((map) => map['taskId'] == taskId)
        .map(CheckInResultMapper.fromMap)
        .toList();

    if (results.isEmpty) return null;

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results.first;
  }

  /// Returns all results for a given [taskId], newest first.
  List<CheckInResult> getResultsByTaskId(String taskId) {
    final results = _resultBox.values
        .cast<Map<String, dynamic>>()
        .where((map) => map['taskId'] == taskId)
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  /// Returns all results for a given [accountId], newest first.
  List<CheckInResult> getResultsByAccountId(String accountId) {
    final results = _resultBox.values
        .cast<Map<String, dynamic>>()
        .where((map) => map['accountId'] == accountId)
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  /// Returns all results across all tasks, newest first.
  List<CheckInResult> getAllResults() {
    final results = _resultBox.values
        .cast<Map<String, dynamic>>()
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  // ── Private helpers ──────────────────────────────────────────────

  Future<void> _deleteResultsByTaskId(String taskId) async {
    final results = getResultsByTaskId(taskId);
    for (final result in results) {
      await _resultBox.delete(result.id);
    }
  }
}

/// Riverpod provider for [CheckInLocalDataSource].
final checkInLocalDataSourceProvider = Provider<CheckInLocalDataSource>((ref) {
  return CheckInLocalDataSource(
    Hive.box(_taskBoxName),
    Hive.box(_resultBoxName),
  );
});
