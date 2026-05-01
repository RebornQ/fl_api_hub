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
  ///
  /// Expects the **inner data** object from the New API status check response:
  /// ```json
  /// {
  ///   "enabled": true,
  ///   "stats": {
  ///     "checked_in_today": true,
  ///     "records": [{"checkin_date": "2026-05-02", "quota_awarded": 1083226}],
  ///     "total_quota": 500000
  ///   }
  /// }
  /// ```
  static CheckInStatusDto fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    final records = (stats?['records'] as List<dynamic>?) ?? [];
    return CheckInStatusDto(
      checkedInToday: stats?['checked_in_today'] as bool?,
      checkedDays: records
          .map((r) {
            final date = (r as Map<String, dynamic>)['checkin_date'] as String?;
            return date != null ? int.tryParse(date.split('-').last) : null;
          })
          .whereType<int>()
          .toList(),
      totalReward: (stats?['total_quota'] as num?)?.toDouble(),
    );
  }
}
