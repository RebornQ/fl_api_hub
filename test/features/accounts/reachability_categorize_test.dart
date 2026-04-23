import 'package:fl_all_api_hub/core/error/app_exception.dart';
import 'package:fl_all_api_hub/core/network/reachability_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categorizeFailure', () {
    final dummyRequest = RequestOptions(path: '/test');

    test('5xx DioException → FailCategory.http5xx', () {
      final error = DioException(
        requestOptions: dummyRequest,
        response: Response(requestOptions: dummyRequest, statusCode: 503),
        type: DioExceptionType.badResponse,
      );

      expect(categorizeFailure(error), FailCategory.http5xx);
    });

    test('4xx DioException → FailCategory.http4xx', () {
      final error = DioException(
        requestOptions: dummyRequest,
        response: Response(requestOptions: dummyRequest, statusCode: 401),
        type: DioExceptionType.badResponse,
      );

      expect(categorizeFailure(error), FailCategory.http4xx);
    });

    test('connection timeout DioException → FailCategory.network', () {
      final error = DioException(
        requestOptions: dummyRequest,
        type: DioExceptionType.connectionTimeout,
      );

      expect(categorizeFailure(error), FailCategory.network);
    });

    test('AuthException with 401 → FailCategory.http4xx', () {
      const error = AuthException(message: 'unauthorized', statusCode: 401);

      expect(categorizeFailure(error), FailCategory.http4xx);
    });

    test('NetworkException with 500 → FailCategory.http5xx', () {
      const error = NetworkException(
        message: 'internal server error',
        statusCode: 500,
      );

      expect(categorizeFailure(error), FailCategory.http5xx);
    });

    test('NetworkException without statusCode → FailCategory.network', () {
      const error = NetworkException(message: 'no connection');

      expect(categorizeFailure(error), FailCategory.network);
    });

    test('unknown error type → FailCategory.network', () {
      expect(categorizeFailure(Exception('boom')), FailCategory.network);
    });
  });
}
