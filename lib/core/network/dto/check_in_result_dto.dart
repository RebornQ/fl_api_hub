/// DTO for `POST /api/user/checkin` response data.
///
/// Represents the result of a daily check-in attempt.
library;

import 'check_in_data_dto.dart';

/// Check-in execution result from the API.
class CheckInResultDto {
  /// Detailed check-in data (date and quota awarded).
  final CheckInDataDto? data;

  /// Whether the check-in was successful.
  final bool success;

  /// Human-readable message (e.g. "签到成功", "今日已签到").
  final String? message;

  const CheckInResultDto({this.data, required this.success, this.message});

  /// Parses a raw JSON map into a [CheckInResultDto].
  factory CheckInResultDto.fromJson(Map<String, dynamic> json) {
    return CheckInResultDto(
      data: json['data'] != null
          ? CheckInDataDto.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}
