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
/// The provider also owns the lifecycle of the dev-tools
/// [RequestLoggerInterceptor]: when [requestLoggerEnabledProvider] becomes
/// `true`, a fresh interceptor is attached that pushes completed entries
/// into the ring buffer. When the switch flips back to `false`, the
/// interceptor is detached so captured headers/bodies stop flowing — but
/// already-recorded entries are left in place (users clear them
/// explicitly from the list page).
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();

  void attachLogger() {
    // Ensure at most one instance is attached; removing first keeps the
    // method idempotent when called from the initial-state branch below
    // and again from ref.listen.
    client.removeInterceptorsOfType<RequestLoggerInterceptor>();
    client.addInterceptor(
      RequestLoggerInterceptor(
        onComplete: (entry) =>
            ref.read(requestLogBufferProvider.notifier).add(entry),
      ),
    );
  }

  void detachLogger() {
    client.removeInterceptorsOfType<RequestLoggerInterceptor>();
  }

  // Sync initial state. `ref.read` does not establish a subscription so
  // the provider does not rebuild on switch changes; we drive the dynamic
  // mount through `ref.listen` below.
  if (ref.read(requestLoggerEnabledProvider)) {
    attachLogger();
  }

  ref.listen<bool>(requestLoggerEnabledProvider, (previous, next) {
    if (previous == next) return;
    if (next) {
      attachLogger();
    } else {
      detachLogger();
    }
  });

  return client;
});
