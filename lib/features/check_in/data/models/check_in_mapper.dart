/// Mappers for [CheckInTask] and [CheckInResult] domain entities.
///
/// Used by local data sources to serialize/deserialize check-in data for
/// Hive storage. Enum values are stored as strings for forward compatibility.
library;

import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';

/// Converts [CheckInTask] entities to and from JSON-compatible maps.
class CheckInTaskMapper {
  const CheckInTaskMapper._();

  /// Serializes a [CheckInTask] into a persistable map.
  static Map<String, dynamic> toMap(CheckInTask task) => {
    'id': task.id,
    'accountId': task.accountId,
    'enabled': task.enabled,
    'scheduleTime': task.scheduleTime,
    'lastRunAt': task.lastRunAt?.toIso8601String(),
    'nextRunAt': task.nextRunAt?.toIso8601String(),
    'createdAt': task.createdAt.toIso8601String(),
    'updatedAt': task.updatedAt.toIso8601String(),
  };

  /// Deserializes a map back into a [CheckInTask].
  static CheckInTask fromMap(Map<String, dynamic> map) {
    return CheckInTask(
      id: map['id'] as String,
      accountId: map['accountId'] as String,
      enabled: map['enabled'] as bool? ?? true,
      scheduleTime: map['scheduleTime'] as String? ?? '08:00',
      lastRunAt: map['lastRunAt'] != null
          ? DateTime.parse(map['lastRunAt'] as String)
          : null,
      nextRunAt: map['nextRunAt'] != null
          ? DateTime.parse(map['nextRunAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

/// Converts [CheckInResult] entities to and from JSON-compatible maps.
class CheckInResultMapper {
  const CheckInResultMapper._();

  /// Serializes a [CheckInResult] into a persistable map.
  static Map<String, dynamic> toMap(CheckInResult result) => {
    'id': result.id,
    'taskId': result.taskId,
    'accountId': result.accountId,
    'status': result.status.name,
    'message': result.message,
    'rewardAmount': result.rewardAmount,
    'checkinDate': result.checkinDate,
    'quotaAwarded': result.quotaAwarded,
    'executedAt': result.executedAt.toIso8601String(),
  };

  /// Deserializes a map back into a [CheckInResult].
  static CheckInResult fromMap(Map<String, dynamic> map) {
    return CheckInResult(
      id: map['id'] as String,
      taskId: map['taskId'] as String,
      accountId: map['accountId'] as String,
      status: CheckInStatus.values.byName(map['status'] as String),
      message: map['message'] as String?,
      rewardAmount: (map['rewardAmount'] as num?)?.toDouble(),
      checkinDate: map['checkinDate'] as String?,
      quotaAwarded: map['quotaAwarded'] as int?,
      executedAt: DateTime.parse(map['executedAt'] as String),
    );
  }
}
