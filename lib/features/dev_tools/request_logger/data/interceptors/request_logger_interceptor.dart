/// Dio interceptor that captures every request/response into a
/// [RequestLogEntry] and emits it through a caller-supplied callback.
///
/// Lifecycle:
/// 1. `onRequest` stamps a monotonic id and a start timestamp on
///    `options.extra` so subsequent response/error callbacks can compute
///    the elapsed duration.
/// 2. `onResponse` / `onError` build an entry from the captured options +
///    terminal event and invoke [onComplete]. The headers recorded are
///    the **outgoing** headers after any earlier interceptor (e.g.
///    `AuthInterceptor`) has already run, which is the debugging value
///    we want. Headers are stored **unredacted**; UI layer is responsible
///    for masking sensitive values during display.
///
/// The interceptor does **not** depend on Riverpod directly; wiring to a
/// `Notifier` lives in the entry-point batch (B2).
library;

import 'package:dio/dio.dart';

import '../../domain/entities/request_log_entry.dart';
import '../utils/body_serializer.dart';

/// Callback invoked once per completed request (success or failure).
typedef RequestLogSink = void Function(RequestLogEntry entry);

/// Captures Dio request/response pairs into [RequestLogEntry]s.
class RequestLoggerInterceptor extends Interceptor {
  /// Invoked on every terminal event (response **or** error).
  final RequestLogSink onComplete;

  /// Monotonic counter shared across the interceptor's lifetime.
  int _counter = 0;

  RequestLoggerInterceptor({required this.onComplete});

  static const String _extraIdKey = '__rl_id';
  static const String _extraStartKey = '__rl_start';
  static const String _extraCorrelationIdKey = '__correlation_id';
  static const String _extraProxyLabelKey = '__proxy_label';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_extraIdKey] = ++_counter;
    options.extra[_extraStartKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    onComplete(_buildEntry(response.requestOptions, response: response));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    onComplete(_buildEntry(err.requestOptions, error: err));
    handler.next(err);
  }

  RequestLogEntry _buildEntry(
    RequestOptions options, {
    Response? response,
    DioException? error,
  }) {
    final id = options.extra[_extraIdKey] as int? ?? 0;
    final startedAt =
        options.extra[_extraStartKey] as DateTime? ?? DateTime.now();
    final endedAt = DateTime.now();

    final responseObj = response ?? error?.response;
    final contentType = responseObj?.headers.value('content-type');

    return RequestLogEntry(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
      elapsed: endedAt.difference(startedAt),
      method: options.method.toUpperCase(),
      url: options.uri.toString(),
      query: Map<String, dynamic>.of(options.queryParameters),
      requestHeaders: _flattenDynamicHeaders(options.headers),
      requestBody: serializeRequestBody(options.data),
      statusCode: responseObj?.statusCode,
      responseHeaders: responseObj == null
          ? const {}
          : _flattenHeaders(responseObj.headers.map),
      responseBody: responseObj == null
          ? null
          : serializeResponseBody(responseObj.data, contentType: contentType),
      errorType: error?.type.name,
      errorMessage: error?.message ?? error?.error?.toString(),
      correlationId: options.extra[_extraCorrelationIdKey] as String?,
      proxyLabel: options.extra[_extraProxyLabelKey] as String?,
    );
  }

  Map<String, String> _flattenHeaders(Map<String, List<String>> map) {
    return {for (final e in map.entries) e.key: e.value.join(', ')};
  }

  /// Converts `Map<String, dynamic>` headers (Dio's outgoing request format)
  /// to `Map<String, String>` without redaction.
  Map<String, String> _flattenDynamicHeaders(Map<String, dynamic> headers) {
    return {for (final e in headers.entries) e.key: e.value?.toString() ?? ''};
  }
}
