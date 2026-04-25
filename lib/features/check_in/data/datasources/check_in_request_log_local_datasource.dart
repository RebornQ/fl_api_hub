/// Local data source for check-in request log persistence.
///
/// Stores [RequestLogEntry] maps in a dedicated Hive box keyed by a
/// synthetic composite key (`correlationId_entryId`) so that all logs
/// belonging to a single check-in execution can be queried efficiently.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';
import '../models/check_in_request_log_mapper.dart';

/// Box name for check-in request log storage.
const kCheckInRequestLogBoxName = 'check_in_request_logs';

/// Local CRUD operations for check-in request logs.
class CheckInRequestLogLocalDataSource {
  final Box _box;

  CheckInRequestLogLocalDataSource(this._box);

  /// Persists a request log entry associated with a [correlationId].
  Future<void> saveLog(String correlationId, RequestLogEntry entry) async {
    final key = _compositeKey(correlationId, entry.id);
    await _box.put(key, RequestLogLogMapper.toMap(entry, correlationId));
  }

  /// Returns all request logs for a given [correlationId], sorted by start time.
  List<RequestLogEntry> getLogsByCorrelationId(String correlationId) {
    final entries = <RequestLogEntry>[];
    for (final raw in _box.values) {
      final map = Map<String, dynamic>.from(raw as Map);
      if (map['correlationId'] == correlationId) {
        entries.add(RequestLogLogMapper.fromMap(map));
      }
    }
    entries.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return entries;
  }

  /// Deletes all request logs for a given [correlationId].
  ///
  /// Uses [Box.toMap] to iterate actual key-value pairs so deletions target
  /// the real stored keys — reconstructing keys from values is fragile.
  Future<void> deleteLogsByCorrelationId(String correlationId) async {
    final keysToDelete = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      final map = entry.value;
      if (map is Map && map['correlationId'] == correlationId) {
        keysToDelete.add(entry.key);
      }
    }
    await _box.deleteAll(keysToDelete);
  }

  /// Returns all persisted request logs, newest first.
  List<RequestLogEntry> getAllLogs() {
    final entries = _box.values
        .map(
          (e) =>
              RequestLogLogMapper.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  /// Returns the total number of persisted request logs.
  int get totalCount => _box.length;

  /// Deletes all persisted request logs.
  Future<void> deleteAll() async {
    await _box.clear();
  }

  String _compositeKey(String correlationId, int entryId) =>
      '${correlationId}_$entryId';
}

/// Riverpod provider for [CheckInRequestLogLocalDataSource].
final checkInRequestLogLocalDataSourceProvider =
    Provider<CheckInRequestLogLocalDataSource>((ref) {
      return CheckInRequestLogLocalDataSource(
        Hive.box(kCheckInRequestLogBoxName),
      );
    });
