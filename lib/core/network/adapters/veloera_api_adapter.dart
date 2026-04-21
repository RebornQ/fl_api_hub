/// Veloera-specific site adapter.
///
/// Veloera mostly follows the new-api compatible surface, but the daily
/// check-in endpoint uses the snake-case path `/api/user/check_in` (with an
/// underscore) instead of `/api/user/checkin`. All other endpoints are
/// inherited from [CommonApiAdapter].
///
/// See `input/API-EndPoint.md` — "Veloera" section — for the canonical
/// endpoint contract.
library;

import '../../result/result.dart';
import '../api_request.dart';
import '../dto/check_in_result_dto.dart';
import '../site_type.dart';
import 'common_api_adapter.dart';

/// Site adapter for Veloera deployments.
///
/// Only [checkIn] is overridden; everything else falls through to
/// [CommonApiAdapter], which uses the `{success, message, data}` envelope
/// shared by the new-api family.
class VeloeraApiAdapter extends CommonApiAdapter {
  VeloeraApiAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.veloera;

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) {
    return performRequest<CheckInResultDto>(
      method: 'POST',
      path: '/api/user/check_in',
      request: request,
      fromJson: CheckInResultDto.fromJson,
    );
  }
}
