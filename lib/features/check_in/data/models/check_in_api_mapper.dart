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
  /// - If a reward is present and positive → [CheckInStatus.success].
  /// - If the message suggests the user already checked in →
  ///   [CheckInStatus.skipped].
  /// - Otherwise → [CheckInStatus.failed].
  static CheckInStatus inferStatus(CheckInResultDto dto) {
    if (dto.reward != null && dto.reward! > 0) {
      return CheckInStatus.success;
    }
    final message = dto.message?.toLowerCase() ?? '';
    if (message.contains('already') || message.contains('已签到')) {
      return CheckInStatus.skipped;
    }
    // If there is no error message and no reward, it might still be success.
    if (dto.message != null &&
        !message.contains('fail') &&
        !message.contains('error')) {
      return CheckInStatus.success;
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
      rewardAmount: dto.reward,
      executedAt: DateTime.now(),
    );
  }
}
