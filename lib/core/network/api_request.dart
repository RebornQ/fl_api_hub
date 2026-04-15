/// Per-request API configuration object.
///
/// Immutable bundle carrying the target [baseUrl], authentication credential
/// [authToken], and the [authType] strategy. Passed from the repository layer
/// through the remote data source into the [SiteAdapter] so that every remote
/// call is scoped to a specific account's context.
library;

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

  const ApiRequest({
    required this.baseUrl,
    this.authToken,
    required this.authType,
  });
}
