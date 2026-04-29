/// OneHub-specific site adapter.
///
/// OneHub follows the common/new-api surface for most operations but has
/// a different user groups endpoint: `GET /api/user_group_map` returns
/// `Record<string, OneHubUserGroupInfo>` with additional fields.
///
/// All other endpoints are inherited from [CommonApiAdapter].
library;

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../api_request.dart';
import '../dto/group_dto.dart';
import '../site_type.dart';
import 'common_api_adapter.dart';

/// Site adapter for OneHub deployments.
///
/// Only [fetchGroups] is overridden to use OneHub's user group map endpoint;
/// everything else falls through to [CommonApiAdapter].
class OneHubAdapter extends CommonApiAdapter {
  OneHubAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.oneHub;

  // ── Group operations ─────────────────────────────────────────────

  @override
  Future<Result<GroupListDto>> fetchGroups(ApiRequest request) async {
    // Strategy: prefer user_group_map, fallback to site groups.
    final userGroups = await _fetchUserGroupMap(request);
    if (userGroups is Success<GroupListDto>) {
      return userGroups;
    }
    // Fallback to site groups (inherited from CommonApiAdapter).
    return fetchSiteGroupsFallback(request);
  }

  /// Fetches user group mapping from `GET /api/user_group_map`.
  ///
  /// Response format: `Record<string, OneHubUserGroupInfo>` where each value
  /// contains `{ id, symbol, name, ratio, ... }`.
  Future<Result<GroupListDto>> _fetchUserGroupMap(ApiRequest request) async {
    try {
      final response = await dioClient
          .getDio(proxy: request.proxy)
          .request(
            '/api/user_group_map',
            options: Options(method: 'GET', extra: buildExtra(request)),
          );

      final json = response.data as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        return Failure<GroupListDto>(
          NetworkException(
            message:
                json['message']?.toString() ?? 'Fetch user group map failed',
          ),
        );
      }

      final data = json['data'];
      if (data is Map<String, dynamic>) {
        final groups = <GroupDto>[];
        for (final entry in data.entries) {
          if (entry.value is Map<String, dynamic>) {
            groups.add(
              GroupDto.fromOneHubUserGroup(
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
}
