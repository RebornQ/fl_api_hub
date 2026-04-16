import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/core/network/auth_interceptor.dart';

void main() {
  late AuthInterceptor interceptor;

  setUp(() {
    interceptor = AuthInterceptor();
  });

  /// Helper: creates a real [RequestOptions] with the given [extra] map and
  /// runs it through [AuthInterceptor.onRequest]. Returns the (mutated)
  /// options so assertions can inspect headers and baseUrl.
  ///
  /// The interceptor modifies `options` in place before calling
  /// `handler.next(options)`, so we can inspect the same object afterwards.
  RequestOptions intercept(RequestOptions options) {
    interceptor.onRequest(options, RequestInterceptorHandler());
    return options;
  }

  group('AuthInterceptor', () {
    test('accessToken authType injects Authorization Bearer header', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          extra: {'apiAuthToken': 'my-token-123', 'apiAuthType': 'accessToken'},
        ),
      );

      expect(options.headers['Authorization'], 'Bearer my-token-123');
      expect(options.headers.containsKey('Cookie'), isFalse);
    });

    test('cookie authType injects Cookie session header', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          extra: {'apiAuthToken': 'session-abc', 'apiAuthType': 'cookie'},
        ),
      );

      expect(options.headers['Cookie'], 'session=session-abc');
      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('none authType does not inject any auth header', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          extra: {'apiAuthToken': 'ignored-token', 'apiAuthType': 'none'},
        ),
      );

      expect(options.headers.containsKey('Authorization'), isFalse);
      expect(options.headers.containsKey('Cookie'), isFalse);
    });

    test('apiBaseUrl in extras overrides options.baseUrl', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          baseUrl: 'https://default.example.com',
          extra: {'apiBaseUrl': 'https://custom.example.com'},
        ),
      );

      expect(options.baseUrl, 'https://custom.example.com');
    });

    test('missing extras does not crash and makes no header modifications', () {
      final options = intercept(RequestOptions(path: '/test'));

      expect(options.headers.containsKey('Authorization'), isFalse);
      expect(options.headers.containsKey('Cookie'), isFalse);
    });

    test('empty authToken does not inject auth header', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          extra: {'apiAuthToken': '', 'apiAuthType': 'accessToken'},
        ),
      );

      expect(options.headers.containsKey('Authorization'), isFalse);
      expect(options.headers.containsKey('Cookie'), isFalse);
    });

    test('combined baseUrl override and auth injection', () {
      final options = intercept(
        RequestOptions(
          path: '/test',
          baseUrl: 'https://old.example.com',
          extra: {
            'apiBaseUrl': 'https://new.example.com',
            'apiAuthToken': 'combined-token',
            'apiAuthType': 'accessToken',
          },
        ),
      );

      expect(options.baseUrl, 'https://new.example.com');
      expect(options.headers['Authorization'], 'Bearer combined-token');
    });
  });
}
