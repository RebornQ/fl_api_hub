/// Dio interceptor that injects authentication headers into outgoing requests.
///
/// The actual token retrieval is deferred via an optional [tokenProvider]
/// callback. This will be wired to [SecureStore] once the account data layer
/// is implemented.
library;

import 'package:dio/dio.dart';

/// Intercepts outgoing requests to inject the Authorization header.
class AuthInterceptor extends Interceptor {
  /// Optional callback that returns the auth token for a given request.
  ///
  /// When `null` or when it returns `null`, no auth header is added.
  /// Will be connected to SecureStore in a later batch.
  final String? Function(RequestOptions options)? tokenProvider;

  AuthInterceptor({this.tokenProvider});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenProvider?.call(options);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
