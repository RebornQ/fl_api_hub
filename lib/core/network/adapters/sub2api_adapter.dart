/// Sub2API-specific site adapter for token/key management.
///
/// Sub2API uses a different endpoint structure (`/api/v1/keys/*`) and response
/// envelope (`{code, message, data}`) compared to the common/new-api family.
/// Account and check-in operations are not supported and throw when called.
library;

import 'package:dio/dio.dart';
import 'package:meta/meta.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/network/api_request.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/dto/access_token_dto.dart';
import '../../../core/network/dto/check_in_result_dto.dart';
import '../../../core/network/dto/check_in_status_dto.dart';
import '../../../core/network/dto/group_dto.dart';
import '../../../core/network/dto/site_status_dto.dart';
import '../../../core/network/dto/token_dto.dart';
import '../../../core/network/dto/user_info_dto.dart';
import '../../../core/network/site_adapter.dart';
import '../../../core/network/site_type.dart';

/// 1 USD = 500000 internal quota units.
const _kQuotaPerUnit = 500000;

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
        // Sub2API pages start from 1, Common from 0.
        queryParameters: {'page': page + 1, 'page_size': size},
      );

      final json = response.data as Map<String, dynamic>;
      if (!_isSuccess(json)) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API list keys failed',
          ),
        );
      }

      final data = json['data'];
      if (data is List) {
        return Success(TokenListDto.fromJson({'items': data}));
      }
      if (data is Map<String, dynamic>) {
        return Success(TokenListDto.fromJson(data));
      }

      return const Success(TokenListDto(tokens: []));
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
    int? quota,
    DateTime? expiresAt,
    bool unlimitedQuota = false,
    String? group,
  }) async {
    try {
      final data = <String, dynamic>{'name': name};

      // Quota: convert internal units -> USD. 0 means unlimited.
      data['quota'] = unlimitedQuota ? 0 : (quota ?? 0) ~/ _kQuotaPerUnit;

      // Expiration: Sub2API create uses expires_in_days, not expires_at.
      if (expiresAt != null) {
        final days = expiresAt.difference(DateTime.now()).inDays;
        data['expires_in_days'] = days > 0 ? days : 0;
      } else {
        data['expires_in_days'] = 0; // never expires
      }

      // Group: resolve group name to group_id via groups/available.
      if (group != null && group.isNotEmpty) {
        final groupId = await _resolveGroupId(request, group);
        if (groupId != null) {
          data['group_id'] = groupId;
        }
      }

      final response = await _dioClient.dio.request(
        '/api/v1/keys',
        options: Options(method: 'POST', extra: _buildExtra(request)),
        data: data,
      );

      final json = response.data as Map<String, dynamic>;
      if (!_isSuccess(json)) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API create key failed',
          ),
        );
      }

      // Sub2API create returns data: null on success.
      final responseData = json['data'];
      if (responseData is Map<String, dynamic>) {
        return Success(TokenDto.fromJson(responseData));
      }
      // Success with null data — return an empty DTO.
      return const Success(TokenDto());
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
    String? group,
  }) async {
    try {
      final data = <String, dynamic>{'name': name};

      // Quota: convert internal units -> USD.
      // For update, the API expects the total quota (remaining + used) in USD.
      // The caller should ensure quota includes used amount.
      if (quota != null) {
        data['quota'] = quota ~/ _kQuotaPerUnit;
      } else {
        data['quota'] = 0; // unlimited
      }

      // Expiration: Sub2API update uses expires_at (ISO 8601).
      if (expiresAt != null) {
        data['expires_at'] = expiresAt.toIso8601String();
      } else {
        data['expires_at'] = ''; // never expires
      }

      data['status'] = 'active';

      // Group: resolve group name to group_id via groups/available.
      if (group != null && group.isNotEmpty) {
        final groupId = await _resolveGroupId(request, group);
        if (groupId != null) {
          data['group_id'] = groupId;
        }
      }

      final response = await _dioClient.dio.request(
        '/api/v1/keys/$tokenId',
        options: Options(method: 'PUT', extra: _buildExtra(request)),
        data: data,
      );

      final json = response.data as Map<String, dynamic>;
      if (!_isSuccess(json)) {
        return Failure(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API update key failed',
          ),
        );
      }

      // Sub2API update returns data: null on success.
      final responseData = json['data'];
      if (responseData is Map<String, dynamic>) {
        return Success(TokenDto.fromJson(responseData));
      }
      return const Success(TokenDto());
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
      final response = await _dioClient.dio.delete(
        '/api/v1/keys/$tokenId',
        options: Options(extra: _buildExtra(request)),
      );

      final json = response.data as Map<String, dynamic>;
      if (!_isSuccess(json)) {
        return Failure<void>(
          NetworkException(
            message: json['message']?.toString() ?? 'Sub2API delete key failed',
          ),
        );
      }

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

  // ── Group operations ──────────────────────────────────────────────

  @override
  Future<Result<GroupListDto>> fetchGroups(ApiRequest request) async {
    try {
      // Request both endpoints in parallel using Future.wait.
      // On rates failure, still proceed with available groups (degraded mode).
      final results = await Future.wait<dynamic>([
        _fetchAvailableGroups(request),
        _fetchGroupRates(request),
      ]);

      final availableResult = results[0] as Map<String, dynamic>;
      final ratesResult = results[1] as Map<String, num>?;

      final data = availableResult['data'];
      if (data is! List) {
        return const Success<GroupListDto>(GroupListDto(groups: []));
      }

      // Merge ratio data with priority: rates > rate_multiplier > 1.
      final groups = data.whereType<Map<String, dynamic>>().map((json) {
        final groupId = json['id']?.toString();
        final rateMultiplier = (json['rate_multiplier'] as num?)?.toDouble();

        // Priority: rates table > rate_multiplier > 1 (default).
        final mergedRatio = _resolveGroupRatio(
          groupId: groupId,
          rates: ratesResult,
          rateMultiplier: rateMultiplier,
        );

        return GroupDto.fromSub2ApiGroup(json, ratio: mergedRatio);
      }).toList();

      return Success<GroupListDto>(GroupListDto(groups: groups));
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

  /// Fetches available groups from `GET /api/v1/groups/available`.
  ///
  /// Returns the raw JSON response map.
  /// Throws on network or parsing errors so that [fetchGroups] can handle
  /// them in its outer catch block.
  Future<Map<String, dynamic>> _fetchAvailableGroups(ApiRequest request) async {
    final response = await _dioClient.dio.request(
      '/api/v1/groups/available',
      options: Options(method: 'GET', extra: _buildExtra(request)),
    );

    final json = response.data as Map<String, dynamic>;
    if (!_isSuccess(json)) {
      throw NetworkException(
        message: json['message']?.toString() ?? 'Sub2API fetch groups failed',
      );
    }
    return json;
  }

  /// Fetches group rates from `GET /api/v1/groups/rates`.
  ///
  /// Returns `Record<string, number>` mapping group ID to ratio,
  /// or `null` on failure (degraded mode).
  Future<Map<String, num>?> _fetchGroupRates(ApiRequest request) async {
    try {
      final response = await _dioClient.dio.request(
        '/api/v1/groups/rates',
        options: Options(method: 'GET', extra: _buildExtra(request)),
      );

      final json = response.data as Map<String, dynamic>;
      if (!_isSuccess(json)) {
        return null;
      }

      final data = json['data'];
      if (data is Map<String, dynamic>) {
        // Convert to Map<String, num> for type safety.
        return data.map((key, value) => MapEntry(key, value as num));
      }
      return null;
    } catch (_) {
      // On failure, return null to indicate degraded mode.
      return null;
    }
  }

  /// Resolves the group ratio with priority: rates > rate_multiplier > 1.
  double _resolveGroupRatio({
    required String? groupId,
    required Map<String, num>? rates,
    required double? rateMultiplier,
  }) {
    // Priority 1: rates table match by group ID.
    if (groupId != null && rates != null) {
      final rateFromTable = rates[groupId];
      if (rateFromTable != null) {
        return rateFromTable.toDouble();
      }
    }

    // Priority 2: group's own rate_multiplier.
    if (rateMultiplier != null) {
      return rateMultiplier;
    }

    // Priority 3: default to 1.
    return 1.0;
  }

  // ── Auth helpers (unsupported) ──────────────────────────────────

  @override
  Future<Result<AccessTokenDto>> createAccessToken(ApiRequest request) async {
    return const Failure(
      NetworkException(message: 'Sub2API uses JWT auth, not access token'),
    );
  }

  // ── Internal helpers ────────────────────────────────────────────

  /// Checks if the Sub2API envelope indicates success (`code` is 0).
  @protected
  bool _isSuccess(Map<String, dynamic> json) {
    final code = json['code'];
    return code == 0;
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

  /// Resolves a group name to a Sub2API group ID.
  ///
  /// Queries the groups/available endpoint and finds the matching group by name.
  /// Returns `null` if the group is not found.
  Future<int?> _resolveGroupId(ApiRequest request, String groupName) async {
    final groupsResult = await fetchGroups(request);
    if (groupsResult is Success<GroupListDto>) {
      for (final group in groupsResult.data.groups) {
        if (group.name == groupName && group.id != null) {
          return int.tryParse(group.id!);
        }
      }
    }
    return null;
  }
}
