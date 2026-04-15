/// DTO for `GET /api/user/checkin?month=YYYY-MM` response data.
///
/// Represents the monthly check-in status, including which days the user
/// has already checked in.
library;

/// Monthly check-in status from the API.
class CheckInStatusDto {
  /// Whether the user has already checked in today.
  final bool? checkedInToday;

  /// List of day numbers that have been checked in this month.
  final List<int>? checkedDays;

  /// Total reward accumulated this month.
  final double? totalReward;

  const CheckInStatusDto({
    this.checkedInToday,
    this.checkedDays,
    this.totalReward,
  });

  /// Parses a raw JSON map into a [CheckInStatusDto].
  static CheckInStatusDto fromJson(Map<String, dynamic> json) {
    return CheckInStatusDto(
      checkedInToday: json['checked_in_today'] as bool?,
      checkedDays: (json['checked_days'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      totalReward: (json['total_reward'] as num?)?.toDouble(),
    );
  }
}
