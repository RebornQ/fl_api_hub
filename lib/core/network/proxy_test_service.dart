/// Service for testing proxy connectivity.
///
/// Sends a lightweight HTTP request through a given [ProxyConfig] (or direct)
/// to verify that the proxy is reachable and can forward traffic. Returns a
/// typed [ProxyTestResult] indicating success, timeout, authentication failure,
/// or other network errors.
///
/// On Web platforms, always returns [ProxyTestFailure] because proxy
/// configuration is managed by the browser.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dio_client.dart';
import 'proxy_config.dart';

/// Default probe URL used when no specific target is provided.
///
/// Google's generate_204 endpoint returns an empty body with HTTP 204,
/// making it a lightweight connectivity check.
const String kDefaultProbeUrl = 'https://www.gstatic.com/generate_204';

/// Sealed result type for proxy connectivity tests.
sealed class ProxyTestResult {
  const ProxyTestResult();
}

/// Proxy connectivity test succeeded.
class ProxyTestSuccess extends ProxyTestResult {
  /// HTTP status code returned by the target.
  final int statusCode;

  /// Round-trip latency from request to response.
  final Duration latency;

  const ProxyTestSuccess(this.statusCode, this.latency);

  @override
  String toString() =>
      'ProxyTestSuccess(statusCode: $statusCode, latency: ${latency.inMilliseconds}ms)';
}

/// Proxy connectivity test failed.
class ProxyTestFailure extends ProxyTestResult {
  /// Human-readable failure reason suitable for display in the UI.
  final String reason;

  /// Original exception that caused the failure, if any.
  final Object? cause;

  const ProxyTestFailure(this.reason, [this.cause]);

  @override
  String toString() => 'ProxyTestFailure(reason: $reason)';
}

/// Service that tests whether a proxy configuration can reach a target URL.
class ProxyTestService {
  final DioClient _client;

  ProxyTestService(this._client);

  /// Tests connectivity through [proxy] to [targetUrl].
  ///
  /// When [targetUrl] is not provided, defaults to [kDefaultProbeUrl].
  /// The [timeout] parameter controls how long to wait for a response.
  ///
  /// Returns:
  /// - [ProxyTestSuccess] when the request completes with an acceptable status.
  /// - [ProxyTestFailure] with a descriptive reason on timeout, auth failure,
  ///   DNS resolution failure, or other network errors.
  Future<ProxyTestResult> test({
    required ProxyConfig? proxy,
    String? targetUrl,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // Web platform: proxy is managed by the browser, cannot test.
    if (kIsWeb) {
      return const ProxyTestFailure('Web 平台代理由浏览器决定，无法测试');
    }

    final url = targetUrl ?? kDefaultProbeUrl;
    final dio = _client.getDio(proxy: proxy);

    final stopwatch = Stopwatch()..start();

    try {
      final response = await dio
          .get(
            url,
            options: Options(
              receiveTimeout: timeout,
              sendTimeout: timeout,
              // Do not send auth headers for probe requests.
              extra: {
                'apiBaseUrl': '',
                'apiAuthToken': null,
                'apiAuthType': 'none',
                'apiUserId': null,
              },
            ),
          )
          .timeout(timeout);

      stopwatch.stop();

      final statusCode = response.statusCode ?? 0;

      // For the default probe URL, success means 204.
      // For custom target URLs, accept any 2xx status.
      final isProbeUrl = url == kDefaultProbeUrl;
      final isSuccess = isProbeUrl
          ? statusCode == 204
          : statusCode >= 200 && statusCode < 300;

      if (isSuccess) {
        return ProxyTestSuccess(statusCode, stopwatch.elapsed);
      }

      return ProxyTestFailure(
        'HTTP $statusCode',
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        ),
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return _classifyDioException(e, stopwatch.elapsed, proxy);
    } catch (e) {
      stopwatch.stop();
      return ProxyTestFailure(e.toString(), e);
    }
  }

  /// Classifies a [DioException] into a user-friendly [ProxyTestFailure].
  ProxyTestFailure _classifyDioException(
    DioException e,
    Duration elapsed,
    ProxyConfig? proxy,
  ) {
    final proxyLabel = proxy != null
        ? '${proxy.scheme.name}://${proxy.host}:${proxy.port}'
        : null;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ProxyTestFailure(
          '连接超时 (${elapsed.inSeconds}s)${proxyLabel != null ? ' — 代理: $proxyLabel' : ''}',
          e,
        );

      case DioExceptionType.connectionError:
        final message = e.message?.toLowerCase() ?? '';
        // DNS resolution failure.
        if (message.contains('failed host lookup') ||
            message.contains('nodename nor servname') ||
            message.contains('dns')) {
          return ProxyTestFailure(
            'DNS 解析失败${proxyLabel != null ? ' — 代理: $proxyLabel' : ''}',
            e,
          );
        }
        // Proxy authentication failure — typically manifests as connection
        // refused or 407 through the proxy chain.
        if (message.contains('407') ||
            message.contains('proxy authentication')) {
          return ProxyTestFailure('代理认证失败 — 请检查用户名和密码', e);
        }
        // Generic connection error.
        return ProxyTestFailure(
          '连接失败: ${e.message ?? "未知错误"}${proxyLabel != null ? ' — 代理: $proxyLabel' : ''}',
          e,
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 407) {
          return const ProxyTestFailure('代理认证失败 — 请检查用户名和密码');
        }
        return ProxyTestFailure('HTTP $statusCode', e);

      case DioExceptionType.cancel:
        return const ProxyTestFailure('请求已取消');

      case DioExceptionType.badCertificate:
        return const ProxyTestFailure('SSL 证书验证失败');

      case DioExceptionType.unknown:
        final innerMessage = e.message ?? e.error?.toString() ?? '未知错误';
        return ProxyTestFailure(innerMessage, e);
    }
  }
}

/// Riverpod provider for [ProxyTestService].
final proxyTestServiceProvider = Provider<ProxyTestService>((ref) {
  final client = ref.watch(dioClientProvider);
  return ProxyTestService(client);
});
