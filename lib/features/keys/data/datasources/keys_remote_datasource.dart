/// Remote data source for API key / token operations.
///
/// Thin delegation layer that forwards calls to the appropriate [SiteAdapter].
/// Does not perform error handling — exceptions propagate as [Result.failure]
/// from the adapter layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/token_dto.dart';
import '../../../../core/network/site_adapter.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';

/// Remote data source for API key / token operations.
class KeysRemoteDataSource {
  final SiteAdapter _adapter;

  KeysRemoteDataSource(this._adapter);

  /// Lists API tokens with pagination.
  Future<Result<TokenListDto>> listTokens(
    ApiRequest request, {
    int page = 0,
    int size = 100,
  }) => _adapter.listTokens(request, page: page, size: size);

  /// Creates a new API token.
  Future<Result<TokenDto>> createToken(
    ApiRequest request, {
    required String name,
  }) => _adapter.createToken(request, name: name);

  /// Deletes an API token by its server ID.
  Future<Result<void>> deleteToken(
    ApiRequest request, {
    required String tokenId,
  }) => _adapter.deleteToken(request, tokenId: tokenId);

  /// Updates an existing API token's metadata.
  Future<Result<TokenDto>> updateToken(
    ApiRequest request, {
    required String tokenId,
    required String name,
    int? quota,
    DateTime? expiresAt,
  }) => _adapter.updateToken(
    request,
    tokenId: tokenId,
    name: name,
    quota: quota,
    expiresAt: expiresAt,
  );

  /// Resolves a masked token key to the full key value.
  ///
  /// Calls the hidden `POST /api/token/{id}/key` endpoint to retrieve
  /// the unmasked secret.
  Future<Result<TokenDto>> resolveTokenKey(
    ApiRequest request, {
    required String tokenId,
  }) => _adapter.fetchTokenKey(request, tokenId: tokenId);
}

/// Provider for [KeysRemoteDataSource], parameterized by [SiteType].
final keysRemoteDataSourceProvider =
    Provider.family<KeysRemoteDataSource, SiteType>((ref, siteType) {
      final adapter = ref.watch(siteAdapterForTypeProvider(siteType));
      return KeysRemoteDataSource(adapter);
    });
