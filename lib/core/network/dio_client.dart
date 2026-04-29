/// Centralized Dio HTTP client wrapper with proxy-aware instance pooling.
///
/// Maintains a pool of [Dio] instances keyed by proxy configuration.
/// Requests that share the same proxy (or no proxy) reuse the same [Dio]
/// instance. Each instance gets its own [AuthInterceptor] and the shared
/// [RequestLoggerInterceptor] wiring.
///
/// Resolution priority is handled by [ProxyResolver] at the repository layer;
/// this class only manages the lifecycle of Dio instances once the effective
/// proxy is known.
library;

import 'dart:io' show HttpClient, HttpClientBasicCredentials;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/check_in/data/datasources/check_in_request_log_local_datasource.dart';
import '../../features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart';
import '../../features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';
import 'auth_interceptor.dart';
import 'proxy_config.dart';

/// Cache key for the direct (no-proxy) Dio instance.
const String _directKey = '__direct__';

/// Wrapper around a pool of [Dio] instances keyed by proxy configuration.
///
/// Call [getDio] with an optional [ProxyConfig] to obtain a Dio instance
/// configured for that proxy. Instances are cached and reused for the same
/// proxy key. When `proxy` is `null`, the direct-connection Dio is returned.
class DioClient {
  /// Pool of Dio instances, keyed by proxy authority string.
  final Map<String, Dio> _pool = {};

  /// Callback that configures additional interceptors on a freshly created Dio.
  /// Used by [dioClientProvider] to attach the [RequestLoggerInterceptor].
  final void Function(Dio) _configureInterceptors;

  /// Creates a [DioClient] with optional interceptor configuration callback.
  ///
  /// [_configureInterceptors] is invoked once per Dio instance at creation
  /// time, including the default direct-connection instance.
  DioClient(this._configureInterceptors) {
    _pool[_directKey] = _buildDio(proxy: null);
  }

  /// Returns a [Dio] instance configured for the given [proxy].
  ///
  /// If the same proxy key has been requested before, the cached instance
  /// is returned. Otherwise a new Dio is created, configured with the
  /// proxy, and added to the pool.
  Dio getDio({ProxyConfig? proxy}) {
    final key = _keyFor(proxy);
    return _pool.putIfAbsent(key, () => _buildDio(proxy: proxy));
  }

  /// Appends an interceptor to **all** Dio instances in the pool
  /// (existing and future).
  ///
  /// This is needed because the request logger toggle may attach/detach
  /// interceptors after the pool has been created. By adding to all
  /// existing instances and tracking the factory, future instances also
  /// receive the interceptor.
  void addInterceptor(Interceptor interceptor) {
    for (final dio in _pool.values) {
      dio.interceptors.add(interceptor);
    }
  }

  /// Removes every interceptor whose runtime type matches [T] from all
  /// pool instances.
  ///
  /// Used by the request logger wiring to detach the
  /// [RequestLoggerInterceptor] when its switch is turned off; returns the
  /// total number of interceptors removed across all Dio instances.
  int removeInterceptorsOfType<T extends Interceptor>() {
    var total = 0;
    for (final dio in _pool.values) {
      final before = dio.interceptors.length;
      dio.interceptors.removeWhere((i) => i is T);
      total += before - dio.interceptors.length;
    }
    return total;
  }

  // ── Internal helpers ─────────────────────────────────────────────

  /// Builds a new [Dio] instance with the given [proxy] configuration.
  Dio _buildDio({required ProxyConfig? proxy}) {
    final dio = Dio(
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
    dio.interceptors.add(AuthInterceptor());

    // Apply interceptor configuration (e.g. request logger).
    _configureInterceptors(dio);

    // Platform-specific proxy configuration.
    // On web (kIsWeb), proxy is not supported — browser decides routing.
    // On native platforms, configure IOHttpClientAdapter with proxy.
    if (!kIsWeb && proxy != null) {
      _configureProxy(dio, proxy);
    }

    return dio;
  }

  /// Configures the [Dio] instance to route traffic through [proxy].
  ///
  /// Uses [IOHttpClientAdapter] with a custom [HttpClient.findProxy] to
  /// set the proxy endpoint. Proxy authentication (BasicAuth) is added
  /// via [HttpClient.addProxyCredentials] when both username and password
  /// are non-empty.
  void _configureProxy(Dio dio, ProxyConfig proxy) {
    final proxyString = 'PROXY ${proxy.host}:${proxy.port}';

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final httpClient = HttpClient();
        httpClient.findProxy = (uri) => proxyString;

        // Add proxy BasicAuth when credentials are present.
        if (proxy.username != null &&
            proxy.username!.isNotEmpty &&
            proxy.password != null) {
          httpClient.addProxyCredentials(
            proxy.host,
            proxy.port,
            '', // realm — empty string for default realm.
            HttpClientBasicCredentials(proxy.username!, proxy.password!),
          );
        }

        return httpClient;
      },
    );
  }

  /// Computes the pool cache key for a [ProxyConfig].
  ///
  /// Uses [ProxyConfig.authority] which includes scheme, optional username,
  /// host, and port — but never the password.
  static String _keyFor(ProxyConfig? p) => p == null ? _directKey : p.authority;
}

/// Riverpod provider for the application-wide [DioClient].
///
/// The [RequestLoggerInterceptor] is attached during construction via the
/// [_configureInterceptors] callback so every Dio instance in the pool
/// receives it. The callback reads from providers at call time (not capture
/// time), so the enabled/disabled toggle stays responsive.
final dioClientProvider = Provider<DioClient>((ref) {
  // Build the interceptor factory once. It will be called for every new
  // Dio instance created in the pool.
  void configureInterceptors(Dio dio) {
    dio.interceptors.add(
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
  }

  return DioClient(configureInterceptors);
});
