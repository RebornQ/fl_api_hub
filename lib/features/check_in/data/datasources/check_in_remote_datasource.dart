/// Remote data source for check-in operations.
///
/// Thin delegation layer that forwards calls to the appropriate [SiteAdapter].
/// Does not perform error handling — exceptions propagate as [Result.failure]
/// from the adapter layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/check_in_result_dto.dart';
import '../../../../core/network/dto/check_in_status_dto.dart';
import '../../../../core/network/site_adapter.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';

/// Remote data source for check-in operations.
class CheckInRemoteDataSource {
  final SiteAdapter _adapter;

  CheckInRemoteDataSource(this._adapter);

  /// Executes a daily check-in.
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) =>
      _adapter.checkIn(request);

  /// Fetches the check-in status for a given month.
  ///
  /// [month] format: `"YYYY-MM"` (e.g. `"2026-04"`).
  Future<Result<CheckInStatusDto>> fetchCheckInStatus(
    ApiRequest request, {
    required String month,
  }) => _adapter.fetchCheckInStatus(request, month: month);
}

/// Provider for [CheckInRemoteDataSource], parameterized by [SiteType].
final checkInRemoteDataSourceProvider =
    Provider.family<CheckInRemoteDataSource, SiteType>((ref, siteType) {
      final adapter = ref.watch(siteAdapterForTypeProvider(siteType));
      return CheckInRemoteDataSource(adapter);
    });
