/// Centralized Dio HTTP client wrapper.
///
/// Provides a pre-configured Dio instance with sensible defaults for
/// timeout and headers. The base URL is intentionally left empty because
/// the [AuthInterceptor] overrides it per-request via `RequestOptions.extra`.
///
/// Used by all [SiteAdapter] implementations through the [dioClientProvider].
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/check_in/data/datasources/check_in_request_log_local_datasource.dart';
import '../../features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart';
import '../../features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';
import 'auth_interceptor.dart';

/// Wrapper around [Dio] with application-wide configuration.
class DioClient {
  late final Dio _dio;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auth interceptor handles per-request baseUrl and header injection.
    _dio.interceptors.add(AuthInterceptor());
  }

  /// The raw [Dio] instance for use by [SiteAdapter] implementations.
  Dio get dio => _dio;

  /// Appends an interceptor to the client.
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Removes every interceptor whose runtime type matches [T].
  ///
  /// Used by the request logger wiring to detach the
  /// [RequestLoggerInterceptor] when its switch is turned off; returns the
  /// number of interceptors removed so callers can confirm the change.
  int removeInterceptorsOfType<T extends Interceptor>() {
    final before = _dio.interceptors.length;
    _dio.interceptors.removeWhere((i) => i is T);
    return before - _dio.interceptors.length;
  }
}

/// Riverpod provider for the application-wide [DioClient].
///
/// The [RequestLoggerInterceptor] is always attached so that requests with a
/// `correlationId` are always captured for persistence. The in-memory ring
/// buffer is only populated when [requestLoggerEnabledProvider] is `true`.
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();

  // Always attach the interceptor. It captures every request/response;
  // the callback decides what to do with each entry.
  client.addInterceptor(
    RequestLoggerInterceptor(
      onComplete: (entry) {
        // 1. Push to dev-tools in-memory buffer when enabled.
        if (ref.read(requestLoggerEnabledProvider)) {
          ref.read(requestLogBufferProvider.notifier).add(entry);
        }
        // 2. Persist to Hive when a correlation ID is present (e.g. check-in).
        if (entry.correlationId case final cid?) {
          ref
              .read(checkInRequestLogLocalDataSourceProvider)
              .saveLog(cid, entry);
        }
      },
    ),
  );

  return client;
});
