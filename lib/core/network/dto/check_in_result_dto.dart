/// DTO for `POST /api/user/checkin` response data.
///
/// Represents the result of a daily check-in attempt.
library;

/// Check-in execution result from the API.
class CheckInResultDto {
  /// Human-readable message (e.g. "Check-in successful, reward: 0.5").
  final String? message;

  /// Reward amount received from this check-in.
  final double? reward;

  const CheckInResultDto({this.message, this.reward});

  /// Parses a raw JSON map into a [CheckInResultDto].
  static CheckInResultDto fromJson(Map<String, dynamic> json) {
    return CheckInResultDto(
      message: json['message'] as String?,
      reward: (json['reward'] as num?)?.toDouble(),
    );
  }
}
