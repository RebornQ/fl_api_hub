/// Maps [CheckInResultDto] to domain [CheckInResult] entity.
///
/// Converts API-level check-in response data into the domain entity format,
/// including inferring the [CheckInStatus] from the response content.
library;

import '../../../../core/network/dto/check_in_result_dto.dart';
import '../../domain/entities/check_in_result.dart';

/// Utility class for converting [CheckInResultDto] to [CheckInResult].
class CheckInApiMapper {
  const CheckInApiMapper._();

  /// Infers the [CheckInStatus] from a [CheckInResultDto].
  ///
  /// - If success is true → [CheckInStatus.success].
  /// - If success is false and message suggests already checked in →
  ///   [CheckInStatus.alreadyChecked].
  /// - Otherwise → [CheckInStatus.failed].
  ///
  /// Message matching rules (per API doc):
  /// - "already" (any case)
  /// - "已签到" / "已经签到" / "今天已经签到"
  /// - Empty message (AnyRouter specific: success=false + empty msg = already)
  static CheckInStatus inferStatus(CheckInResultDto dto) {
    // Prioritize the success field
    if (dto.success) {
      return CheckInStatus.success;
    }

    // Check message content when success is false
    final message = dto.message;

    // AnyRouter: empty string (not null) means already checked in.
    // Other providers return null for unknown failures.
    if (message != null && message.trim().isEmpty) {
      return CheckInStatus.alreadyChecked;
    }

    final normalizedMessage = message?.toLowerCase() ?? '';

    // Keyword matching for "already checked in"
    if (normalizedMessage.contains('already') ||
        normalizedMessage.contains('已签到') ||
        normalizedMessage.contains('已经签到') ||
        normalizedMessage.contains('今天已经签到')) {
      return CheckInStatus.alreadyChecked;
    }

    return CheckInStatus.failed;
  }

  /// Converts a [CheckInResultDto] to a [CheckInResult] entity.
  ///
  /// [taskId] and [accountId] are required because they are local
  /// associations not present in the API response. [resultId] should
  /// be a freshly generated UUID.
  static CheckInResult toEntity(
    CheckInResultDto dto, {
    required String taskId,
    required String accountId,
    required String resultId,
  }) {
    return CheckInResult(
      id: resultId,
      taskId: taskId,
      accountId: accountId,
      status: inferStatus(dto),
      message: dto.message,
      rewardAmount: dto.data?.quotaAwarded?.toDouble(),
      checkinDate: dto.data?.checkinDate,
      quotaAwarded: dto.data?.quotaAwarded,
      executedAt: DateTime.now(),
    );
  }
}
