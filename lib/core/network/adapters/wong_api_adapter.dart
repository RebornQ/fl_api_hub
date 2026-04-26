/// WONG (wong-gongyi) site adapter.
///
/// WONG follows the common/new-api surface for all Token CRUD operations,
/// except the key resolution endpoint uses `GET` instead of `POST`:
/// - Common: `POST /api/token/{id}/key`
/// - WONG:   `GET  /api/token/{id}/key`
///
/// All other endpoints are inherited from [CommonApiAdapter].
library;

import '../../../core/result/result.dart';
import '../../../core/network/api_request.dart';
import '../../../core/network/dto/token_dto.dart';
import '../../../core/network/site_type.dart';
import 'common_api_adapter.dart';

/// Site adapter for WONG deployments.
///
/// Only [fetchTokenKey] is overridden to use `GET`; everything else falls
/// through to [CommonApiAdapter].
class WongApiAdapter extends CommonApiAdapter {
  WongApiAdapter(super.dioClient);

  @override
  SiteType get siteType => SiteType.wongGongyi;

  @override
  Future<Result<TokenDto>> fetchTokenKey(
    ApiRequest request, {
    required String tokenId,
  }) async {
    return performRequest<TokenDto>(
      method: 'GET',
      path: '/api/token/$tokenId/key',
      request: request,
      fromJson: TokenDto.fromJson,
    );
  }
}
