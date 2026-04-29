/// Immutable snapshot of a single HTTP request/response captured by the
/// request logger.
///
/// Fields marked "pre-processed" are filled in by the logger pipeline:
/// - [requestHeaders] stores **raw** header values; UI layer is responsible
///   for redacting sensitive values (Authorization, Cookie, etc.) during display.
/// - [responseHeaders] are stored raw (not typically sensitive).
/// - [requestBody] / [responseBody] are serialized strings (JSON encoded,
///   FormData summary, or binary placeholder) and preserved in full.
library;

import 'package:meta/meta.dart';

/// A captured HTTP request/response log entry.
@immutable
class RequestLogEntry {
  /// Monotonically increasing id assigned by the interceptor on
  /// [onRequest]; also used as the `ListView` key.
  final int id;

  /// Clock time when [onRequest] fired.
  final DateTime startedAt;

  /// Clock time when [onResponse] / [onError] fired. `null` only when the
  /// entry was built defensively without a terminal event (should not
  /// happen in practice).
  final DateTime? endedAt;

  /// [endedAt] − [startedAt]; `null` only when [endedAt] is `null`.
  final Duration? elapsed;

  /// HTTP method (upper-cased, e.g. `GET`, `POST`).
  final String method;

  /// Full request URL including base + path + query string.
  final String url;

  /// Structured query parameters (also present in [url]); kept separate so
  /// the detail page can render them as a table.
  final Map<String, dynamic> query;

  /// Request headers **stored as raw values** (not redacted).
  /// UI layer should redact sensitive headers (Authorization, Cookie, etc.)
  /// during display via [redactHeaders].
  final Map<String, String> requestHeaders;

  /// Serialized request body (JSON encoded string, FormData summary, etc.);
  /// already truncated to 64 KB when oversized.
  final String? requestBody;

  /// HTTP status code. `null` means transport-level failure and the entry
  /// is classified as [isError].
  final int? statusCode;

  /// Response headers (raw, not sensitive).
  final Map<String, String> responseHeaders;

  /// Serialized response body. `null` when the request failed before
  /// receiving a response, or when the body was empty.
  final String? responseBody;

  /// Free-form error message from [DioException] (only populated for
  /// failed requests).
  final String? errorMessage;

  /// Name of the `DioExceptionType` (e.g. `connectionTimeout`,
  /// `receiveTimeout`, `cancel`, `unknown`).
  final String? errorType;

  /// Optional correlation ID that links this request to a business operation
  /// (e.g. a specific check-in execution). Set via `ApiRequest.correlationId`.
  final String? correlationId;

  /// Proxy label for observability (e.g. `http://proxy.example.com:8080`).
  ///
  /// Populated from `options.extra['__proxy_label']` by the interceptor.
  /// `null` when the request was made without a proxy (direct connection).
  final String? proxyLabel;

  const RequestLogEntry({
    required this.id,
    required this.startedAt,
    required this.method,
    required this.url,
    required this.requestHeaders,
    this.query = const {},
    this.endedAt,
    this.elapsed,
    this.requestBody,
    this.statusCode,
    this.responseHeaders = const {},
    this.responseBody,
    this.errorMessage,
    this.errorType,
    this.correlationId,
    this.proxyLabel,
  });

  /// `true` when there is no status code — transport-level failure.
  bool get isError => statusCode == null;

  /// `true` for 2xx / 3xx responses.
  bool get isSuccess {
    final s = statusCode;
    return s != null && s >= 200 && s < 400;
  }

  /// `true` for 4xx responses.
  bool get isClientError {
    final s = statusCode;
    return s != null && s >= 400 && s < 500;
  }

  /// `true` for 5xx responses.
  bool get isServerError {
    final s = statusCode;
    return s != null && s >= 500 && s < 600;
  }

  /// Short status label for the list tile: the numeric code or `ERR`.
  String get statusLabel => statusCode?.toString() ?? 'ERR';
}
