/// Dio interceptor that injects authentication headers and overrides the
/// base URL on a per-request basis.
///
/// Auth context is read from [RequestOptions.extra]:
/// - `apiBaseUrl`: overrides the Dio default base URL for this request.
/// - `apiAuthToken`: the credential value (token, cookie, etc.).
/// - `apiAuthType`: one of `'accessToken'`, `'cookie'`, or `'none'`.
///
/// This design keeps the interceptor stateless — every request carries its
/// own auth context, allowing a single Dio instance to serve multiple
/// accounts with different base URLs and authentication methods.
library;

import 'package:dio/dio.dart';

import 'site_type.dart';

/// Intercepts outgoing requests to inject per-request authentication and URL.
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 1. Override baseUrl if provided in extras.
    final baseUrl = options.extra['apiBaseUrl'] as String?;
    if (baseUrl != null && baseUrl.isNotEmpty) {
      options.baseUrl = baseUrl;
    }

    // 2. Inject auth header based on auth type.
    final authToken = options.extra['apiAuthToken'] as String?;
    final authTypeName = options.extra['apiAuthType'] as String?;

    if (authToken != null && authToken.isNotEmpty && authTypeName != null) {
      final authType = AuthType.values.byName(authTypeName);
      switch (authType) {
        case AuthType.accessToken:
          options.headers['Authorization'] = 'Bearer $authToken';
        case AuthType.cookie:
          options.headers['Cookie'] = 'session=$authToken';
        case AuthType.none:
          // No authentication header needed.
          break;
      }
    }

    handler.next(options);
  }
}
