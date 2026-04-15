/// Check-in task entity representing a scheduled sign-in operation.
///
/// A [CheckInTask] defines when and how a daily check-in should be performed
/// for a specific [Account]. Actual execution results are stored separately
/// as [CheckInResult] entities.
library;

/// A scheduled check-in task tied to an account.
class CheckInTask {
  /// Unique identifier (UUID v4).
  final String id;

  /// Foreign key to the owning [Account].
  final String accountId;

  /// Whether this task is active and eligible for execution.
  final bool enabled;

  /// Scheduled execution time in "HH:mm" format (e.g. "08:00").
  final String scheduleTime;

  /// Timestamp of the last successful or failed execution.
  /// `null` if never executed.
  final DateTime? lastRunAt;

  /// Timestamp of the next scheduled execution.
  /// `null` if not scheduled.
  final DateTime? nextRunAt;

  /// Timestamp when this task was created.
  final DateTime createdAt;

  /// Timestamp when this task was last modified.
  final DateTime updatedAt;

  const CheckInTask({
    required this.id,
    required this.accountId,
    this.enabled = true,
    this.scheduleTime = '08:00',
    this.lastRunAt,
    this.nextRunAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this task with the given fields replaced.
  CheckInTask copyWith({
    String? id,
    String? accountId,
    bool? enabled,
    String? scheduleTime,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckInTask(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      enabled: enabled ?? this.enabled,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CheckInTask && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CheckInTask(id: $id, accountId: $accountId, enabled: $enabled)';
}
