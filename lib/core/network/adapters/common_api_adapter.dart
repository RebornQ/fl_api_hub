/// Common / new-api compatible site adapter.
///
/// Implements the standard endpoint set shared by: new-api, one-api, one-hub,
/// done-hub, veloera, octopus. These sites follow the same REST API structure
/// and response envelope format (`{success, message, data}`).
///
/// Site-specific adapters can extend this class and override individual
/// methods to handle endpoint differences (e.g. Veloera's check-in paths).
library;

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../api_request.dart';
import '../dio_client.dart';
import '../dto/access_token_dto.dart';
import '../dto/api_response.dart';
import '../dto/check_in_result_dto.dart';
import '../dto/check_in_status_dto.dart';
import '../dto/site_status_dto.dart';
import '../dto/token_dto.dart';
import '../dto/user_info_dto.dart';
import '../site_adapter.dart';
import '../site_type.dart';

/// Concrete [SiteAdapter] for common/new-api compatible backends.
///
/// All methods follow the same pattern:
/// 1. Build Dio [Options] with per-request baseUrl and auth context.
/// 2. Execute the HTTP call via the shared [DioClient].
/// 3. Parse the response envelope via [ApiResponse.fromJson].
/// 4. Return [Result.success] with the typed DTO or [Result.failure] with
///    an [AppException].
class CommonApiAdapter implements SiteAdapter {
  @protected
  final DioClient dioClient;

  CommonApiAdapter(this.dioClient);

  @override
  SiteType get siteType => SiteType.newApi;

  // ── Account operations ──────────────────────────────────────────

  @override
  Future<Result<UserInfoDto>> fetchAccountInfo(ApiRequest request) async {
    return performRequest<UserInfoDto>(
      method: 'GET',
      path: '/api/user/self',
      request: request,
      fromJson: UserInfoDto.fromJson,
    );
  }

  @override
  Future<Result<SiteStatusDto>> fetchSiteStatus(ApiRequest request) async {
    return performRequest<SiteStatusDto>(
      method: 'GET',
      path: '/api/status',
      request: request,
      fromJson: SiteStatusDto.fromJson,
    );
  }

  // ── Check-in operations ─────────────────────────────────────────

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
    try {
      final response = await dioClient.dio.request(
        '/api/user/checkin',
        options: Options(
          method: 'POST',
          extra: {
            'apiBaseUrl': request.baseUrl,
            'apiAuthToken': request.authToken,
            'apiAuthType': request.authType.name,
            'apiUserId': request.userId,
          },
        ),
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
    return performRequest<CheckInStatusDto>(
      method: 'GET',
      path: '/api/user/checkin',
      request: request,
      queryParameters: {'month': month},
      fromJson: CheckInStatusDto.fromJson,
    );
  }

  // ── Token / Key operations ──────────────────────────────────────

  @override
  Future<Result<TokenListDto>> listTokens(
    ApiRequest request, {
    int page = 0,
    int size = 100,
  }) async {
    return performRequest<TokenListDto>(
      method: 'GET',
      path: '/api/token/',
      request: request,
      queryParameters: {'p': page, 'size': size},
      fromJson: TokenListDto.fromJson,
    );
  }

  @override
  Future<Result<TokenDto>> createToken(
    ApiRequest request, {
    required String name,
  }) async {
    return performRequest<TokenDto>(
      method: 'POST',
      path: '/api/token/',
      request: request,
      data: {'name': name},
      fromJson: TokenDto.fromJson,
    );
  }

  @override
  Future<Result<void>> deleteToken(
    ApiRequest request, {
    required String tokenId,
  }) async {
    try {
      await dioClient.dio.delete(
        '/api/token/$tokenId',
        options: _buildOptions(request),
      );
      return const Success<void>(null);
    } on DioException catch (e, st) {
      return Failure<void>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<void>(
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
    return performRequest<TokenDto>(
      method: 'POST',
      path: '/api/token/$tokenId/key',
      request: request,
      fromJson: TokenDto.fromJson,
    );
  }

  // ── Auth helpers ────────────────────────────────────────────────

  @override
  Future<Result<AccessTokenDto>> createAccessToken(ApiRequest request) async {
    return performRequest<AccessTokenDto>(
      method: 'GET',
      path: '/api/user/token',
      request: request,
      fromJson: AccessTokenDto.fromJson,
    );
  }

  // ── Internal helpers ────────────────────────────────────────────

  /// Executes a typed API request with standard error handling.
  ///
  /// This is the shared implementation for all methods that return a typed
  /// DTO from the `ApiResponse.data` field. Marked [protected] so
  /// site-specific subclasses (e.g. [VeloeraApiAdapter]) can override
  /// individual endpoints without duplicating the Dio / envelope plumbing.
  @protected
  Future<Result<T>> performRequest<T>({
    required String method,
    required String path,
    required ApiRequest request,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) async {
    try {
      final response = await dioClient.dio.request(
        path,
        options: Options(
          method: method,
          extra: {
            'apiBaseUrl': request.baseUrl,
            'apiAuthToken': request.authToken,
            'apiAuthType': request.authType.name,
            'apiUserId': request.userId,
          },
        ),
        queryParameters: queryParameters,
        data: data,
      );

      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        fromJson,
      );

      final responseData = apiResponse.data;
      if (apiResponse.success && responseData != null) {
        return Success<T>(responseData);
      }

      return Failure<T>(
        NetworkException(
          message: apiResponse.message ?? 'API returned unsuccessful response',
        ),
      );
    } on DioException catch (e, st) {
      return Failure<T>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<T>(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Builds Dio [Options] with per-request baseUrl and auth context.
  Options _buildOptions(ApiRequest request) {
    return Options(
      extra: {
        'apiBaseUrl': request.baseUrl,
        'apiAuthToken': request.authToken,
        'apiAuthType': request.authType.name,
        'apiUserId': request.userId,
      },
    );
  }
}
