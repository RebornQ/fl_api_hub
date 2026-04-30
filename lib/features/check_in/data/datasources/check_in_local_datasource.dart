/// Local data source for [CheckInTask] and [CheckInResult] entities.
///
/// Tasks and results are stored in separate Hive boxes. Tasks hold the
/// scheduling configuration; results capture individual execution outcomes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'check_in_request_log_local_datasource.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../models/check_in_mapper.dart';

/// Box name for check-in task storage.
const _taskBoxName = 'check_in_tasks';

/// Box name for check-in result storage.
const _resultBoxName = 'check_in_results';

/// Per-account retention cap for [CheckInResult] records.
///
/// At most this many results are kept per `accountId`. Writes beyond the cap
/// cause the oldest records (by `executedAt`) to be deleted automatically.
const kCheckInResultsCapPerAccount = 50;

/// Local CRUD operations for check-in tasks and results.
class CheckInLocalDataSource {
  final Box _taskBox;
  final Box _resultBox;
  final CheckInRequestLogLocalDataSource _requestLogDs;

  CheckInLocalDataSource(this._taskBox, this._resultBox, this._requestLogDs);

  // ── Task operations ──────────────────────────────────────────────

  /// Returns all stored check-in tasks.
  List<CheckInTask> getAllTasks() {
    return _taskBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(CheckInTaskMapper.fromMap)
        .toList();
  }

  /// Returns tasks filtered by [accountId].
  List<CheckInTask> getTasksByAccountId(String accountId) {
    return _taskBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['accountId'] == accountId)
        .map(CheckInTaskMapper.fromMap)
        .toList();
  }

  /// Returns a single task by [id], or `null` if not found.
  CheckInTask? getTaskById(String id) {
    final raw = _taskBox.get(id);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);
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
  ///
  /// After writing, automatically prunes records for the same `accountId`
  /// down to [kCheckInResultsCapPerAccount] by deleting the oldest entries
  /// (by `executedAt`).
  Future<void> saveResult(CheckInResult result) async {
    await _resultBox.put(result.id, CheckInResultMapper.toMap(result));
    await pruneAccountResults(result.accountId);
  }

  /// Returns the most recent result for a given [taskId].
  ///
  /// Returns `null` if no results exist for the task.
  CheckInResult? getLatestResult(String taskId) {
    final results = _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
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
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['taskId'] == taskId)
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  /// Returns all results for a given [accountId], newest first.
  List<CheckInResult> getResultsByAccountId(String accountId) {
    final results = _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['accountId'] == accountId)
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  /// Returns all results across all tasks, newest first.
  List<CheckInResult> getAllResults() {
    final results = _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(CheckInResultMapper.fromMap)
        .toList();

    results.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return results;
  }

  /// Returns the latest [CheckInResult] for each distinct `accountId`.
  ///
  /// Scans the box once, groups by `accountId`, picks the entry with the
  /// newest `executedAt` per group, and returns the resulting list sorted
  /// newest-first.
  List<CheckInResult> getLatestResultPerAccount() {
    final byAccount = <String, CheckInResult>{};
    for (final raw in _resultBox.values) {
      final map = Map<String, dynamic>.from(raw as Map);
      final result = CheckInResultMapper.fromMap(map);
      final existing = byAccount[result.accountId];
      if (existing == null || result.executedAt.isAfter(existing.executedAt)) {
        byAccount[result.accountId] = result;
      }
    }

    final latest = byAccount.values.toList();
    latest.sort((a, b) => b.executedAt.compareTo(a.executedAt));
    return latest;
  }

  /// Returns a page of results for [accountId], newest first.
  ///
  /// Uses simple in-memory skip/take over the account's full history. Per-
  /// account retention is capped at [kCheckInResultsCapPerAccount], so the
  /// scan cost is bounded.
  ///
  /// When [offset] is greater than or equal to the total count, returns an
  /// empty list.
  List<CheckInResult> getResultsByAccountIdPaged(
    String accountId, {
    required int limit,
    required int offset,
  }) {
    final results = getResultsByAccountId(accountId);
    if (offset >= results.length) return const [];
    return results.skip(offset).take(limit).toList();
  }

  /// Returns the total number of results persisted for [accountId].
  int countResultsByAccountId(String accountId) {
    return _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['accountId'] == accountId)
        .length;
  }

  /// Deletes every result belonging to [accountId].
  ///
  /// Also removes the associated request logs for each deleted result.
  /// Returns the number of records removed.
  Future<int> deleteAllResultsByAccountId(String accountId) async {
    final idsToDelete = _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['accountId'] == accountId)
        .map((map) => map['id'] as String)
        .toList();
    for (final id in idsToDelete) {
      await _requestLogDs.deleteLogsByCorrelationId(id);
      await _resultBox.delete(id);
    }
    return idsToDelete.length;
  }

  /// Prunes results for [accountId] so that at most [keep] records remain.
  ///
  /// Deletes the oldest entries first (by `executedAt`). Returns the number
  /// of records removed. No-op when the account already has at most [keep]
  /// records.
  Future<int> pruneAccountResults(
    String accountId, {
    int keep = kCheckInResultsCapPerAccount,
  }) async {
    final results = getResultsByAccountId(accountId); // newest-first
    if (results.length <= keep) return 0;
    final toDelete = results.skip(keep).toList();
    for (final r in toDelete) {
      await _requestLogDs.deleteLogsByCorrelationId(r.id);
      await _resultBox.delete(r.id);
    }
    return toDelete.length;
  }

  /// Prunes every account's results down to [keep] entries.
  ///
  /// Intended for one-shot migration on app startup. Returns the total
  /// number of records removed across all accounts.
  Future<int> migrateResultsToCap({
    int keep = kCheckInResultsCapPerAccount,
  }) async {
    final accountIds = _resultBox.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((map) => map['accountId'] as String)
        .toSet();
    var totalPruned = 0;
    for (final accountId in accountIds) {
      totalPruned += await pruneAccountResults(accountId, keep: keep);
    }
    return totalPruned;
  }

  // ── Private helpers ──────────────────────────────────────────────

  Future<void> _deleteResultsByTaskId(String taskId) async {
    final results = getResultsByTaskId(taskId);
    for (final result in results) {
      await _requestLogDs.deleteLogsByCorrelationId(result.id);
      await _resultBox.delete(result.id);
    }
  }
}

/// Riverpod provider for [CheckInLocalDataSource].
final checkInLocalDataSourceProvider = Provider<CheckInLocalDataSource>((ref) {
  return CheckInLocalDataSource(
    Hive.box(_taskBoxName),
    Hive.box(_resultBoxName),
    ref.read(checkInRequestLogLocalDataSourceProvider),
  );
});
