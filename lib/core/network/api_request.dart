/// Per-request API configuration object.
///
/// Immutable bundle carrying the target [baseUrl], authentication credential
/// [authToken], the [authType] strategy, and the upstream [userId] that
/// New API compatible backends require in the `New-API-User` header. Passed
/// from the repository layer through the remote data source into the
/// [SiteAdapter] so that every remote call is scoped to a specific account's
/// context.
library;

import 'proxy_config.dart';
import 'site_type.dart';

/// Configuration for a single API request targeting a specific account.
class ApiRequest {
  /// Base URL of the target API site (e.g. "https://api.example.com").
  final String baseUrl;

  /// Authentication credential (token, cookie value, etc.).
  /// `null` when [authType] is [AuthType.none].
  final String? authToken;

  /// Authentication strategy to apply for this request.
  final AuthType authType;

  /// Upstream user id reported by the site's `/api/user/self` response.
  ///
  /// New API and most of its forks additionally require the caller to echo
  /// this id back via the `New-API-User` HTTP header — Bearer token alone is
  /// not enough on stricter deployments. Set to `null` (or any non-positive
  /// value) when the id is not yet known; the interceptor will then omit the
  /// header and let the backend fall back to token-based identification.
  final int? userId;

  /// Optional correlation ID used to associate a network request with a
  /// business operation (e.g. a check-in result). When non-null, the
  /// interceptor will persist the captured [RequestLogEntry] so it can be
  /// retrieved later by this ID.
  final String? correlationId;

  /// Resolved proxy configuration for this request.
  ///
  /// Set by the repository layer after consulting [ProxyResolver]. When
  /// `null`, the request goes through a direct connection. When non-null,
  /// the [SiteAdapter] passes this to [DioClient.getDio] to obtain a
  /// proxy-configured Dio instance.
  final ProxyConfig? proxy;

  const ApiRequest({
    required this.baseUrl,
    this.authToken,
    required this.authType,
    this.userId,
    this.correlationId,
    this.proxy,
  });
}
