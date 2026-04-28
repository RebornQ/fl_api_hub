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
import '../dto/group_dto.dart';
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
    try {
      final response = await dioClient.dio.request(
        '/api/token/',
        options: Options(method: 'GET', extra: buildExtra(request)),
        queryParameters: {'p': page, 'size': size},
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<TokenListDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'List tokens failed',
          ),
        );
      }

      final data = json['data'];
      // Format A: direct array — {"success":true, "data":[...]}
      if (data is List) {
        return Success<TokenListDto>(TokenListDto.fromJson({'items': data}));
      }
      // Format B: paginated object — {"success":true, "data":{"items":[...],...}}
      if (data is Map<String, dynamic>) {
        return Success<TokenListDto>(TokenListDto.fromJson(data));
      }

      return const Success<TokenListDto>(TokenListDto(tokens: []));
    } on DioException catch (e, st) {
      return Failure<TokenListDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<TokenListDto>(
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
    int? quota,
    DateTime? expiresAt,
    bool unlimitedQuota = false,
    String? group,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'remain_quota': quota ?? 0,
        'expired_time': expiresAt != null
            ? expiresAt.millisecondsSinceEpoch ~/ 1000
            : -1,
        'unlimited_quota': unlimitedQuota,
        'model_limits_enabled': false,
        'model_limits': '',
        'allow_ips': '',
        'group': group ?? '',
      };

      final response = await dioClient.dio.request(
        '/api/token/',
        options: Options(method: 'POST', extra: buildExtra(request)),
        data: data,
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<TokenDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'Create token failed',
          ),
        );
      }

      // API returns data: null on success — return empty DTO.
      final responseData = json['data'];
      if (responseData is Map<String, dynamic>) {
        return Success<TokenDto>(TokenDto.fromJson(responseData));
      }
      return const Success<TokenDto>(TokenDto());
    } on DioException catch (e, st) {
      return Failure<TokenDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<TokenDto>(
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
      final response = await dioClient.dio.delete(
        '/api/token/$tokenId',
        options: buildOptions(request),
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<void>(
          NetworkException(
            message: json['message']?.toString() ?? 'Delete token failed',
          ),
        );
      }

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
  Future<Result<TokenDto>> updateToken(
    ApiRequest request, {
    required String tokenId,
    required String name,
    int? quota,
    DateTime? expiresAt,
    String? group,
  }) async {
    try {
      final data = <String, dynamic>{
        'id': int.tryParse(tokenId),
        'name': name,
        'remain_quota': quota ?? 0,
        'expired_time': expiresAt != null
            ? expiresAt.millisecondsSinceEpoch ~/ 1000
            : -1,
        'unlimited_quota': quota == null,
        'model_limits_enabled': false,
        'model_limits': '',
        'allow_ips': '',
        'group': group ?? '',
      };

      final response = await dioClient.dio.request(
        '/api/token/',
        options: Options(method: 'PUT', extra: buildExtra(request)),
        data: data,
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<TokenDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'Update token failed',
          ),
        );
      }

      // API returns data: null on success — return empty DTO.
      final responseData = json['data'];
      if (responseData is Map<String, dynamic>) {
        return Success<TokenDto>(TokenDto.fromJson(responseData));
      }
      return const Success<TokenDto>(TokenDto());
    } on DioException catch (e, st) {
      return Failure<TokenDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<TokenDto>(
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

  // ── Group operations ─────────────────────────────────────────────

  @override
  Future<Result<GroupListDto>> fetchGroups(ApiRequest request) async {
    // Strategy: prefer user groups, fallback to site groups.
    final userGroups = await _fetchUserGroups(request);
    if (userGroups is Success<GroupListDto>) {
      return userGroups;
    }
    // Fallback to site groups.
    return fetchSiteGroupsFallback(request);
  }

  /// Fetches user-specific groups from `GET /api/user/self/groups`.
  ///
  /// Response format: `Record<string, {desc, ratio}>` — keys are group names.
  Future<Result<GroupListDto>> _fetchUserGroups(ApiRequest request) async {
    try {
      final response = await dioClient.dio.request(
        '/api/user/self/groups',
        options: Options(method: 'GET', extra: buildExtra(request)),
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<GroupListDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'Fetch user groups failed',
          ),
        );
      }

      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final groups = <GroupDto>[];
        for (final entry in data.entries) {
          if (entry.value is Map<String, dynamic>) {
            groups.add(
              GroupDto.fromCommonUserGroup(
                entry.key,
                entry.value as Map<String, dynamic>,
              ),
            );
          }
        }
        return Success<GroupListDto>(GroupListDto(groups: groups));
      }

      return const Success<GroupListDto>(GroupListDto(groups: []));
    } on DioException catch (e, st) {
      return Failure<GroupListDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<GroupListDto>(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Fetches all site groups from `GET /api/group`.
  ///
  /// Response format: `string[]` — array of group names.
  /// Visible to subclasses (e.g. [OneHubAdapter]) for fallback delegation.
  @protected
  Future<Result<GroupListDto>> fetchSiteGroupsFallback(
    ApiRequest request,
  ) async {
    try {
      final response = await dioClient.dio.request(
        '/api/group',
        options: Options(method: 'GET', extra: buildExtra(request)),
      );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<GroupListDto>(
          NetworkException(
            message: json['message']?.toString() ?? 'Fetch site groups failed',
          ),
        );
      }

      final data = json['data'];
      if (data is List) {
        final groups = data
            .whereType<String>()
            .map(GroupDto.fromCommonSiteGroup)
            .toList();
        return Success<GroupListDto>(GroupListDto(groups: groups));
      }

      return const Success<GroupListDto>(GroupListDto(groups: []));
    } on DioException catch (e, st) {
      return Failure<GroupListDto>(mapToAppException(e, st));
    } catch (e, st) {
      return Failure<GroupListDto>(
        UnknownException(
          message: e.toString(),
          originalError: e,
          stackTrace: st,
        ),
      );
    }
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
        options: Options(method: method, extra: buildExtra(request)),
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

  /// Builds the per-request extra map carried through Dio [Options].
  @protected
  Map<String, dynamic> buildExtra(ApiRequest request) {
    final extra = <String, dynamic>{
      'apiBaseUrl': request.baseUrl,
      'apiAuthToken': request.authToken,
      'apiAuthType': request.authType.name,
      'apiUserId': request.userId,
    };
    if (request.correlationId case final id?) {
      extra['__correlation_id'] = id;
    }
    return extra;
  }

  /// Builds Dio [Options] with per-request baseUrl and auth context.
  @protected
  Options buildOptions(ApiRequest request) {
    return Options(extra: buildExtra(request));
  }
}
