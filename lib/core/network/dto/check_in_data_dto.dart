/// DTO for the `data` field in New-API check-in response.
///
/// Contains detailed information about the check-in result.
library;

/// Check-in data from the API response.
class CheckInDataDto {
  /// Check-in date in YYYY-MM-DD format.
  final String? checkinDate;

  /// Quota awarded from this check-in.
  final int? quotaAwarded;

  const CheckInDataDto({this.checkinDate, this.quotaAwarded});

  /// Parses a raw JSON map into a [CheckInDataDto].
  factory CheckInDataDto.fromJson(Map<String, dynamic> json) {
    return CheckInDataDto(
      checkinDate: json['checkin_date'] as String?,
      quotaAwarded: json['quota_awarded'] as int?,
    );
  }
}
