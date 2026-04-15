/// Centralized Dio HTTP client wrapper.
///
/// Provides a pre-configured Dio instance with sensible defaults for
/// timeout, headers, and interceptor management. Used by all remote data
/// sources through the [dioClientProvider].
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';

/// Wrapper around [Dio] with application-wide configuration.
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add auth interceptor with no-op token provider for now.
    _dio.interceptors.add(AuthInterceptor());
  }

  /// The raw [Dio] instance for use by [SiteAdapter] implementations.
  Dio get dio => _dio;

  /// Appends an interceptor to the client.
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }
}

/// Riverpod provider for the application-wide [DioClient].
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});
