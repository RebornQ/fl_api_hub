/// DoneHub-specific site adapter.
///
/// DoneHub extends OneHub with a paginated site groups endpoint.
/// The `fetchGroups()` strategy is:
/// 1. Try OneHub's `GET /api/user_group_map`
/// 2. Fallback to DoneHub's paginated `GET /api/group/?page=&size=`
///
/// This differs from Common's `GET /api/group` (no pagination) endpoint.
library;

import 'package:dio/dio.dart';

import '../../error/app_exception.dart';
import '../../error/failure_mapper.dart';
import '../../result/result.dart';
import '../api_request.dart';
import '../dto/group_dto.dart';
import '../site_type.dart';
import 'onehub_adapter.dart';

/// Site adapter for DoneHub deployments.
///
/// Inherits OneHub's adapter surface and overrides [fetchGroups] to use
/// DoneHub's paginated site groups endpoint as fallback instead of Common's
/// non-paginated `/api/group`.
class DoneHubAdapter extends OneHubAdapter {
  DoneHubAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.doneHub;

  // ── Group operations ─────────────────────────────────────────────

  @override
  Future<Result<GroupListDto>> fetchGroups(ApiRequest request) async {
    // Strategy: prefer OneHub user_group_map (via super), fallback to DoneHub
    // paginated site groups.
    final userGroups = await _fetchUserGroupMap(request);
    if (userGroups is Success<GroupListDto>) {
      return userGroups;
    }
    // Fallback to DoneHub paginated site groups.
    return _fetchDoneHubSiteGroups(request);
  }

  /// Fetches user group mapping from `GET /api/user_group_map`.
  ///
  /// Mirrors [OneHubAdapter._fetchUserGroupMap] because Dart library-private
  /// methods are inaccessible from this compilation unit.
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

  /// Fetches all site groups from DoneHub's paginated `GET /api/group/`.
  ///
  /// DoneHub uses pagination with `page` (1-indexed) and `size` parameters.
  /// Maximum 100 pages x 100 items = 10,000 groups.
  Future<Result<GroupListDto>> _fetchDoneHubSiteGroups(
    ApiRequest request,
  ) async {
    try {
      const maxPages = 100;
      const pageSize = 100;
      final allGroups = <Map<String, dynamic>>[];
      var currentPage = 1;
      var hasMore = true;

      while (hasMore && currentPage <= maxPages) {
        final response = await dioClient
            .getDio(proxy: request.proxy)
            .request(
              '/api/group/',
              options: Options(method: 'GET', extra: buildExtra(request)),
              queryParameters: {'page': currentPage, 'size': pageSize},
            );

        final json = response.data as Map<String, dynamic>;
        final success = json['success'] as bool? ?? false;
        if (!success) {
          return Failure<GroupListDto>(
            NetworkException(
              message:
                  json['message']?.toString() ?? 'Fetch site groups failed',
            ),
          );
        }

        final data = json['data'];
        if (data is List) {
          final pageGroups = data.whereType<Map<String, dynamic>>().toList();
          allGroups.addAll(pageGroups);

          // Check if we should continue paging.
          final totalCount = json['total_count'] as int? ?? 0;
          hasMore = allGroups.length < totalCount;
          currentPage++;
        } else {
          hasMore = false;
        }
      }

      // Extract symbol -> trim -> filter empty -> dedupe via Set.
      final symbols = allGroups
          .map((group) => (group['symbol'] as String?)?.trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final groups = symbols.map(GroupDto.fromCommonSiteGroup).toList();
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
}
