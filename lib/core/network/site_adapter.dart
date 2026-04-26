/// Abstract interface for site-specific API adapters.
///
/// Each [SiteType] has its own [SiteAdapter] implementation that translates
/// the common API surface into site-specific request/response handling.
/// The adapter pattern decouples business logic from individual site quirks.
///
/// All methods take an [ApiRequest] that carries per-request context
/// (baseUrl, auth token, auth type) and return typed DTOs wrapped in
/// [Result] for explicit error handling.
library;

import '../result/result.dart';
import 'api_request.dart';
import 'dto/access_token_dto.dart';
import 'dto/check_in_result_dto.dart';
import 'dto/check_in_status_dto.dart';
import 'dto/site_status_dto.dart';
import 'dto/token_dto.dart';
import 'dto/user_info_dto.dart';
import 'site_type.dart';

/// Interface that every site-specific API adapter must implement.
///
/// The common/new-api adapter serves as the default implementation.
/// Site-specific adapters (Veloera, Octopus, etc.) can extend or replace
/// individual methods to handle endpoint differences.
abstract class SiteAdapter {
  /// The site type this adapter handles.
  SiteType get siteType;

  // ── Account operations ──────────────────────────────────────────

  /// Fetches account information (username, balance, quota, etc.).
  ///
  /// Endpoint: `GET /api/user/self`
  Future<Result<UserInfoDto>> fetchAccountInfo(ApiRequest request);

  /// Fetches public site status (check-in enabled, version, etc.).
  ///
  /// Endpoint: `GET /api/status`
  Future<Result<SiteStatusDto>> fetchSiteStatus(ApiRequest request);

  // ── Check-in operations ─────────────────────────────────────────

  /// Executes a daily check-in.
  ///
  /// Endpoint: `POST /api/user/checkin`
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request);

  /// Fetches the check-in status for a given month.
  ///
  /// [month] format: `"YYYY-MM"` (e.g. `"2026-04"`).
  /// Endpoint: `GET /api/user/checkin?month={month}`
  Future<Result<CheckInStatusDto>> fetchCheckInStatus(
    ApiRequest request, {
    required String month,
  });

  // ── Token / Key operations ──────────────────────────────────────

  /// Lists API tokens with pagination.
  ///
  /// Endpoint: `GET /api/token/?p={page}&size={size}`
  Future<Result<TokenListDto>> listTokens(
    ApiRequest request, {
    int page = 0,
    int size = 100,
  });

  /// Creates a new API token.
  ///
  /// Endpoint: `POST /api/token/` (Common) or `POST /api/v1/keys` (Sub2API)
  Future<Result<TokenDto>> createToken(
    ApiRequest request, {
    required String name,
    int? quota,
    DateTime? expiresAt,
    bool unlimitedQuota = false,
  });

  /// Deletes an API token by its server ID.
  ///
  /// Endpoint: `DELETE /api/token/{tokenId}`
  Future<Result<void>> deleteToken(
    ApiRequest request, {
    required String tokenId,
  });

  /// Updates an existing API token's metadata.
  ///
  /// Endpoint: `PUT /api/token/`
  Future<Result<TokenDto>> updateToken(
    ApiRequest request, {
    required String tokenId,
    required String name,
    int? quota,
    DateTime? expiresAt,
  });

  /// Resolves a masked token key to the full key value.
  ///
  /// This calls the hidden endpoint that returns the unmasked secret.
  /// Endpoint: `POST /api/token/{tokenId}/key`
  Future<Result<TokenDto>> fetchTokenKey(
    ApiRequest request, {
    required String tokenId,
  });

  // ── Auth helpers ────────────────────────────────────────────────

  /// Creates an access token from a cookie-based session.
  ///
  /// Used for cookie-mode accounts (sub2api, etc.) to obtain a permanent
  /// access token from an active session cookie.
  /// Endpoint: `GET /api/user/token`
  Future<Result<AccessTokenDto>> createAccessToken(ApiRequest request);
}
