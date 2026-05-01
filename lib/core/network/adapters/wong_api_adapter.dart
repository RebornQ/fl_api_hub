/// WONG (wong-gongyi) site adapter.
///
/// WONG follows the common/new-api surface for most operations, with these
/// differences:
/// - Key resolution: `GET /api/token/{id}/key` instead of `POST`
/// - Check-in status: `GET /api/user/checkin` (no month param) with
///   `Cache-Control: no-store` header; response uses `checked_in` field
library;

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../../../core/network/api_request.dart';
import '../../../core/network/dto/check_in_status_dto.dart';
import '../../../core/network/dto/token_dto.dart';
import '../../../core/network/site_type.dart';
import 'common_api_adapter.dart';

/// Site adapter for WONG deployments.
///
/// [fetchTokenKey] and [fetchCheckInStatus] are overridden; everything else
/// falls through to [CommonApiAdapter].
class WongApiAdapter extends CommonApiAdapter {
  WongApiAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.wongGongyi;

  // ── Check-in operations ─────────────────────────────────────────

  @override
  Future<Result<CheckInStatusDto>> fetchCheckInStatus(
    ApiRequest request, {
    required String month,
  }) async {
    try {
      // WONG uses the same endpoint but without month parameter and requires
      // Cache-Control: no-store to bypass caching.
      final response = await dioClient
          .getDio(proxy: request.proxy)
          .request(
            '/api/user/checkin',
            options: Options(
              method: 'GET',
              extra: buildExtra(request),
              headers: {'Cache-Control': 'no-store'},
            ),
          );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<CheckInStatusDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'Fetch check-in status failed',
          ),
        );
      }

      // WONG response: { success, message, data: { checked_in, enabled, quota, ... } }
      final data = json['data'] as Map<String, dynamic>?;
      final checkedIn = data?['checked_in'] as bool?;

      final dto = CheckInStatusDto(
        checkedInToday: checkedIn,
        checkedDays: null, // WONG doesn't provide this
        totalReward: (data?['quota'] as num?)?.toDouble(),
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

  // ── Token operations ──────────────────────────────────────────────

  @override
  Future<Result<TokenDto>> fetchTokenKey(
    ApiRequest request, {
    required String tokenId,
  }) async {
    return performRequest<TokenDto>(
      method: 'GET',
      path: '/api/token/$tokenId/key',
      request: request,
      fromJson: TokenDto.fromJson,
    );
  }
}
