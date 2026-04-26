/// Sub2API-specific site adapter for token/key management.
///
/// Sub2API uses a different endpoint structure (`/api/v1/keys/*`) and response
/// envelope (`{code, message, data}`) compared to the common/new-api family.
/// Account and check-in operations are not supported and throw when called.
library;

import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/network/api_request.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dto/access_token_dto.dart';
import '../../../core/network/dto/check_in_result_dto.dart';
import '../../../core/network/dto/check_in_status_dto.dart';
import '../../../core/network/dto/site_status_dto.dart';
import '../../../core/network/dto/token_dto.dart';
import '../../../core/network/dto/user_info_dto.dart';
import '../../../core/network/site_adapter.dart';
import '../../../core/network/site_type.dart';

/// Site adapter for Sub2API backends.
///
/// Only token/key operations are implemented. Account info, site status, and
/// check-in methods return [UnimplementedError] — Sub2API handles those
/// through its own JWT auth flow outside the standard adapter surface.
class Sub2ApiAdapter implements SiteAdapter {
  final DioClient _dioClient;

  Sub2ApiAdapter(this._dioClient);

  @override
  SiteType get siteType => SiteType.sub2api;

  // ── Account operations (unsupported) ────────────────────────────

  @override
  Future<Result<UserInfoDto>> fetchAccountInfo(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'Sub2API does not support /api/user/self'),
    );
  }

  @override
  Future<Result<SiteStatusDto>> fetchSiteStatus(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'Sub2API does not support /api/status'),
    );
  }

  // ── Check-in operations (unsupported) ───────────────────────────

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'Sub2API does not support check-in'),
    );
  }

  @override
  Future<Result<CheckInStatusDto>> fetchCheckInStatus(
    ApiRequest request, {
    required String month,
  }) async {
    return const Failure(
      NetworkException(message: 'Sub2API does not support check-in status'),
    );
  }

  // ── Token / Key operations ──────────────────────────────────────

  @override
  Future<Result<TokenListDto>> listTokens(
    ApiRequest request, {
    int page = 0,
    int size = 100,
  }) async {
    try {
      final response = await _dioClient.dio.request(
        '/api/v1/keys',
        options: Options(method: 'GET', extra: _buildExtra(request)),
        queryParameters: {'page': page, 'page_size': size},
      );

      final json = response.data as Map<String, dynamic>;
      final data = _unwrapEnvelope(json);
      if (data == null) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API list keys failed',
          ),
        );
      }

      return Success(TokenListDto.fromJson(data));
    } on DioException catch (e, st) {
      return Failure(mapToAppException(e, st));
    } catch (e, st) {
      return Failure(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<TokenDto>> createToken(
    ApiRequest request, {
    required String name,
  }) async {
    try {
      final response = await _dioClient.dio.request(
        '/api/v1/keys',
        options: Options(method: 'POST', extra: _buildExtra(request)),
        data: {'name': name},
      );

      final json = response.data as Map<String, dynamic>;
      final data = _unwrapEnvelope(json);
      if (data == null) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API create key failed',
          ),
        );
      }

      return Success(TokenDto.fromJson(data));
    } on DioException catch (e, st) {
      return Failure(mapToAppException(e, st));
    } catch (e, st) {
      return Failure(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<TokenDto>> updateToken(
    ApiRequest request, {
    required String tokenId,
    required String name,
    int? quota,
    DateTime? expiresAt,
  }) async {
    try {
      final data = <String, dynamic>{'name': name};
      if (quota != null) data['quota'] = quota;
      if (expiresAt != null) {
        data['expires_at'] = expiresAt.toIso8601String();
      }

      final response = await _dioClient.dio.request(
        '/api/v1/keys/$tokenId',
        options: Options(method: 'PUT', extra: _buildExtra(request)),
        data: data,
      );

      final json = response.data as Map<String, dynamic>;
      final unwrapped = _unwrapEnvelope(json);
      if (unwrapped == null) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API update key failed',
          ),
        );
      }

      return Success(TokenDto.fromJson(unwrapped));
    } on DioException catch (e, st) {
      return Failure(mapToAppException(e, st));
    } catch (e, st) {
      return Failure(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteToken(
    ApiRequest request, {
    required String tokenId,
  }) async {
    try {
      await _dioClient.dio.delete(
        '/api/v1/keys/$tokenId',
        options: Options(extra: _buildExtra(request)),
      );
      return const Success(null);
    } on DioException catch (e, st) {
      return Failure(mapToAppException(e, st));
    } catch (e, st) {
      return Failure(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<TokenDto>> fetchTokenKey(
    ApiRequest request, {
    required String tokenId,
  }) async {
    // Sub2API returns full key in list/detail responses, no separate resolve.
    return Failure(
      NetworkException(message: 'Sub2API does not require key resolution'),
    );
  }

  // ── Auth helpers (unsupported) ──────────────────────────────────

  @override
  Future<Result<AccessTokenDto>> createAccessToken(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'Sub2API uses JWT auth, not access token'),
    );
  }

  // ── Internal helpers ────────────────────────────────────────────

  /// Unwraps the Sub2API envelope `{code, message, data}`.
  ///
  /// Returns the `data` field when `code` is 200, `null` otherwise.
  Map<String, dynamic>? _unwrapEnvelope(Map<String, dynamic> json) {
    final code = json['code'];
    if (code == 200 || code == 0) {
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  /// Builds the per-request extra map carried through Dio [Options].
  Map<String, dynamic> _buildExtra(ApiRequest request) {
    return {
      'apiBaseUrl': request.baseUrl,
      'apiAuthToken': request.authToken,
      'apiAuthType': request.authType.name,
      'apiUserId': request.userId,
    };
  }
}
