import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';

/// Test-only [ErrorInterceptorHandler] that swallows [next]. Dio's real
/// handler completes an internal completer with an error when [next] is
/// called; in production the Dio engine awaits that future, but in unit
/// tests nobody does and the async error ends up flagged by the test zone
/// as "unhandled". Swallowing [next] keeps the tests focused on the
/// interceptor's observable side effect — the emitted [RequestLogEntry].
class _SwallowErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException error) {
    // Intentionally empty — see class docs.
  }
}

/// Test-only [ResponseInterceptorHandler] that swallows [next] for the
/// same reason as [_SwallowErrorHandler] — response handlers complete
/// without errors so this is strictly defensive / symmetrical.
class _SwallowResponseHandler extends ResponseInterceptorHandler {
  @override
  void next(Response response) {
    // Intentionally empty — see class docs.
  }
}

void main() {
  late List<RequestLogEntry> sink;
  late RequestLoggerInterceptor interceptor;

  setUp(() {
    sink = [];
    interceptor = RequestLoggerInterceptor(onComplete: sink.add);
  });

  RequestOptions prepare(RequestOptions options) {
    interceptor.onRequest(options, RequestInterceptorHandler());
    return options;
  }

  test('onResponse emits entry with raw (unredacted) headers and elapsed', () {
    final options = prepare(
      RequestOptions(
        method: 'POST',
        baseUrl: 'https://api.example.com',
        path: '/login',
        queryParameters: {'x': '1'},
        headers: {
          'Authorization': 'Bearer sk-1234567890abcdef',
          'Content-Type': 'application/json',
        },
        data: {'u': 'alice', 'p': 'secret'},
      ),
    );

    final response = Response<Object?>(
      requestOptions: options,
      statusCode: 200,
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
      data: {'ok': true},
    );

    interceptor.onResponse(response, _SwallowResponseHandler());

    expect(sink, hasLength(1));
    final entry = sink.single;
    expect(entry.id, greaterThan(0));
    expect(entry.method, 'POST');
    expect(entry.statusCode, 200);
    expect(entry.url, contains('https://api.example.com/login'));
    // Headers are stored raw (unredacted) - UI layer handles redaction.
    expect(entry.requestHeaders['Authorization'], 'Bearer sk-1234567890abcdef');
    expect(entry.requestHeaders['Content-Type'], 'application/json');
    expect(entry.requestBody, '{"u":"alice","p":"secret"}');
    expect(entry.responseBody, '{"ok":true}');
    expect(entry.elapsed, isNotNull);
    expect(entry.elapsed!.inMicroseconds, greaterThanOrEqualTo(0));
    expect(entry.isSuccess, isTrue);
    expect(entry.isError, isFalse);
  });

  test(
    'onError emits entry with null statusCode and errorType for timeout',
    () {
      final options = prepare(
        RequestOptions(
          method: 'GET',
          baseUrl: 'https://api.example.com',
          path: '/slow',
        ),
      );

      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );

      interceptor.onError(err, _SwallowErrorHandler());

      expect(sink, hasLength(1));
      final entry = sink.single;
      expect(entry.statusCode, isNull);
      expect(entry.isError, isTrue);
      expect(entry.statusLabel, 'ERR');
      expect(entry.errorType, 'connectionTimeout');
      expect(entry.errorMessage, 'Connection timed out');
    },
  );

  test('onError with server response records statusCode', () {
    final options = prepare(
      RequestOptions(
        method: 'GET',
        baseUrl: 'https://api.example.com',
        path: '/resource',
      ),
    );

    final response = Response<Object?>(
      requestOptions: options,
      statusCode: 500,
      headers: Headers.fromMap({
        'content-type': ['application/json'],
      }),
      data: {'err': 'internal'},
    );

    final err = DioException(
      requestOptions: options,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Got 500',
    );

    interceptor.onError(err, _SwallowErrorHandler());

    expect(sink, hasLength(1));
    final entry = sink.single;
    expect(entry.statusCode, 500);
    expect(entry.isServerError, isTrue);
    expect(entry.responseBody, '{"err":"internal"}');
    expect(entry.errorType, 'badResponse');
  });

  test('ids are monotonically increasing across requests', () {
    for (var i = 0; i < 3; i++) {
      final options = prepare(RequestOptions(path: '/p$i'));
      interceptor.onResponse(
        Response<Object?>(requestOptions: options, statusCode: 204),
        _SwallowResponseHandler(),
      );
    }

    final ids = sink.map((e) => e.id).toList();
    expect(ids, [ids[0], ids[0] + 1, ids[0] + 2]);
  });
}
