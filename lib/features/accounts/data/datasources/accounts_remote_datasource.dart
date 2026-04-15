/// Remote data source for account-related API operations.
///
/// Thin delegation layer that forwards calls to the appropriate [SiteAdapter].
/// Does not perform error handling — exceptions propagate as [Result.failure]
/// from the adapter layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/site_status_dto.dart';
import '../../../../core/network/dto/user_info_dto.dart';
import '../../../../core/network/site_adapter.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';

/// Remote data source for account operations.
class AccountsRemoteDataSource {
  final SiteAdapter _adapter;

  AccountsRemoteDataSource(this._adapter);

  /// Fetches account information from the remote API.
  Future<Result<UserInfoDto>> fetchAccountInfo(ApiRequest request) =>
      _adapter.fetchAccountInfo(request);

  /// Fetches site status (check-in support, version, etc.).
  Future<Result<SiteStatusDto>> fetchSiteStatus(ApiRequest request) =>
      _adapter.fetchSiteStatus(request);
}

/// Provider for [AccountsRemoteDataSource], parameterized by [SiteType].
final accountsRemoteDataSourceProvider =
    Provider.family<AccountsRemoteDataSource, SiteType>((ref, siteType) {
      final adapter = ref.watch(siteAdapterForTypeProvider(siteType));
      return AccountsRemoteDataSource(adapter);
    });
