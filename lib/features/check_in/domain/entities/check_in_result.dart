/// Check-in result entity recording the outcome of a single execution.
///
/// Each time a [CheckInTask] is executed, a [CheckInResult] is created to
/// capture whether the check-in succeeded, failed, or was skipped, along
/// with any reward information and timing details.
library;

/// Outcome status of a check-in execution.
enum CheckInStatus {
  /// Check-in completed successfully and a reward was received.
  success,

  /// Check-in failed due to an error.
  failed,

  /// Check-in was skipped (e.g. account disabled, already checked in).
  skipped,
}

/// A single check-in execution result.
class CheckInResult {
  /// Unique identifier (UUID v4).
  final String id;

  /// Foreign key to the [CheckInTask] that produced this result.
  final String taskId;

  /// Foreign key to the [Account] this result belongs to.
  final String accountId;

  /// Outcome of this check-in.
  final CheckInStatus status;

  /// Human-readable message (success message, error details, or skip reason).
  final String? message;

  /// Reward amount received (points, quota, currency).
  /// `null` if no reward or on failure/skip.
  final double? rewardAmount;

  /// Timestamp when this check-in was executed.
  final DateTime executedAt;

  const CheckInResult({
    required this.id,
    required this.taskId,
    required this.accountId,
    required this.status,
    this.message,
    this.rewardAmount,
    required this.executedAt,
  });

  /// Whether this result represents a successful check-in.
  bool get isSuccess => status == CheckInStatus.success;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CheckInResult && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CheckInResult(id: $id, status: $status, taskId: $taskId)';
}
