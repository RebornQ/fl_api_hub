/// Veloera-specific site adapter.
///
/// Veloera mostly follows the new-api compatible surface, but the daily
/// check-in endpoint uses the snake-case path `/api/user/check_in` (with an
/// underscore) instead of `/api/user/checkin`. All other endpoints are
/// inherited from [CommonApiAdapter].
///
/// See `input/API-EndPoint.md` — "Veloera" section — for the canonical
/// endpoint contract.
library;

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../api_request.dart';
import '../dto/check_in_result_dto.dart';
import '../dto/check_in_status_dto.dart';
import '../site_type.dart';
import 'common_api_adapter.dart';

/// Site adapter for Veloera deployments.
///
/// [checkIn] and [fetchCheckInStatus] are overridden; everything else falls
/// through to [CommonApiAdapter], which uses the `{success, message, data}`
/// envelope shared by the new-api family.
class VeloeraApiAdapter extends CommonApiAdapter {
  VeloeraApiAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.veloera;

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
    try {
      final response = await dioClient
          .getDio(proxy: request.proxy)
          .request(
            '/api/user/check_in',
            options: Options(method: 'POST', extra: buildExtra(request)),
          );

      // For check-in, we parse the DTO directly from the response without
      // using ApiResponse, because we need to preserve the top-level success
      // and message fields even when success=false (e.g., "already checked in").
      // The Mapper layer (CheckInApiMapper) will determine the actual status
      // (success/alreadyChecked/failed) based on the DTO content.
      final dto = CheckInResultDto.fromJson(
        response.data as Map<String, dynamic>,
      );

      return Success<CheckInResultDto>(dto);
    } on DioException catch (e, st) {
      return Failure<CheckInResultDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<CheckInResultDto>(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<CheckInStatusDto>> fetchCheckInStatus(
    ApiRequest request, {
    required String month,
  }) async {
    try {
      // Veloera uses a separate endpoint without month parameter.
      final response = await dioClient
          .getDio(proxy: request.proxy)
          .request(
            '/api/user/check_in_status',
            options: Options(method: 'GET', extra: buildExtra(request)),
          );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<CheckInStatusDto>(
          NetworkException(
            message:
                json['message']?.toString() ?? 'Fetch check-in status failed',
          ),
        );
      }

      // Veloera response: { success, data: { can_check_in: boolean } }
      // can_check_in: true = can check in (not checked in), false = already checked in
      final data = json['data'] as Map<String, dynamic>?;
      final canCheckIn = data?['can_check_in'] as bool?;

      // Map to CheckInStatusDto:
      // - can_check_in == true  → checkedInToday = false (can still check in)
      // - can_check_in == false → checkedInToday = true (already checked in)
      // - can_check_in == null  → not supported, return empty DTO
      final dto = CheckInStatusDto(
        checkedInToday: canCheckIn != null ? !canCheckIn : null,
        checkedDays: null, // Veloera doesn't provide this
        totalReward: null, // Veloera doesn't provide this
      );

      return Success<CheckInStatusDto>(dto);
    } on DioException catch (e, st) {
      return Failure<CheckInStatusDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<CheckInStatusDto>(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
