/// AnyRouter-specific site adapter.
///
/// AnyRouter uses a completely different check-in API surface:
/// - Endpoint: `POST /api/user/sign_in` (not `/checkin`)
/// - Header: `X-Requested-With: XMLHttpRequest` (required)
/// - Auth: Cookie-only (no Access Token support)
/// - Envelope: `{code, ret, success, message}` (no data field)
/// - Dual-purpose: same endpoint for status check and execution
library;

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../api_request.dart';
import '../dio_client.dart';
import '../dto/access_token_dto.dart';
import '../dto/check_in_result_dto.dart';
import '../dto/check_in_status_dto.dart';
import '../dto/group_dto.dart';
import '../dto/site_status_dto.dart';
import '../dto/token_dto.dart';
import '../dto/user_info_dto.dart';
import '../site_adapter.dart';
import '../site_type.dart';

/// Site adapter for AnyRouter deployments.
///
/// Only check-in operations are implemented. Account info, tokens, and groups
/// return unsupported errors — AnyRouter handles those through its own flow.
class AnyRouterAdapter implements SiteAdapter {
  final DioClient _dioClient;

  AnyRouterAdapter(this._dioClient);

  @override
  SiteType get siteType => SiteType.anyrouter;

  // ── Account operations (unsupported) ────────────────────────────

  @override
  Future<Result<UserInfoDto>> fetchAccountInfo(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support /api/user/self'),
    );
  }

  @override
  Future<Result<SiteStatusDto>> fetchSiteStatus(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support /api/status'),
    );
  }

  // ── Check-in operations ─────────────────────────────────────────

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
    try {
      final response = await _dioClient
          .getDio(proxy: request.proxy)
          .request(
            '/api/user/sign_in',
            data: {},
            options: Options(
              method: 'POST',
              extra: _buildExtra(request),
              headers: {'X-Requested-With': 'XMLHttpRequest'},
            ),
          );

      // AnyRouter uses a different envelope: {code, ret, success, message}
      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      final message = json['message'] as String?;

      // Build DTO - AnyRouter has no data field, so we infer status from
      // success and message.
      final dto = CheckInResultDto(
        success: success,
        message: message,
        data: null, // AnyRouter doesn't return data
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
    // AnyRouter uses the same endpoint for status check (dual-purpose).
    // We call checkIn and infer the status from the response.
    final result = await checkIn(request);
    return result.when(
      onSuccess: (dto) {
        // If success and message indicates successful check-in, they weren't
        // checked in before. If message is empty or indicates "already", they
        // were already checked in.
        final message = dto.message?.toLowerCase() ?? '';
        final alreadyChecked = message.isEmpty ||
            message.contains('already') ||
            message.contains('已经签到') ||
            message.contains('已签到');

        return Success<CheckInStatusDto>(
          CheckInStatusDto(
            checkedInToday: alreadyChecked,
            checkedDays: null,
            totalReward: null,
          ),
        );
      },
      onFailure: (e) => Failure<CheckInStatusDto>(e),
    );
  }

  // ── Token / Key operations (unsupported) ────────────────────────

  @override
  Future<Result<TokenListDto>> listTokens(
    ApiRequest request, {
    int page = 0,
    int size = 100,
  }) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support token management'),
    );
  }

  @override
  Future<Result<TokenDto>> createToken(
    ApiRequest request, {
    required String name,
    int? quota,
    DateTime? expiresAt,
    bool unlimitedQuota = false,
    String? group,
  }) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support token management'),
    );
  }

  @override
  Future<Result<void>> deleteToken(
    ApiRequest request, {
    required String tokenId,
  }) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support token management'),
    );
  }

  @override
  Future<Result<TokenDto>> updateToken(
    ApiRequest request, {
    required String tokenId,
    required String name,
    int? quota,
    DateTime? expiresAt,
    String? group,
  }) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support token management'),
    );
  }

  @override
  Future<Result<TokenDto>> fetchTokenKey(
    ApiRequest request, {
    required String tokenId,
  }) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support token management'),
    );
  }

  // ── Group operations (unsupported) ───────────────────────────────

  @override
  Future<Result<GroupListDto>> fetchGroups(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'AnyRouter does not support group management'),
    );
  }

  // ── Auth helpers (unsupported) ───────────────────────────────────

  @override
  Future<Result<AccessTokenDto>> createAccessToken(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'AnyRouter uses cookie auth only'),
    );
  }

  // ── Internal helpers ────────────────────────────────────────────

  /// Builds the per-request extra map carried through Dio [Options].
  Map<String, dynamic> _buildExtra(ApiRequest request) {
    final extra = <String, dynamic>{
      'apiBaseUrl': request.baseUrl,
      'apiAuthToken': request.authToken,
      'apiAuthType': request.authType.name,
      'apiUserId': request.userId,
    };
    if (request.correlationId case final id?) {
      extra['__correlation_id'] = id;
    }
    if (request.proxy case final proxy?) {
      extra['__proxy_label'] =
          '${proxy.scheme.name}://${proxy.host}:${proxy.port}';
    }
    return extra;
  }
}
