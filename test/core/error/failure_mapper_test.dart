import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_api_hub/core/error/app_exception.dart';
import 'package:fl_api_hub/core/error/failure_mapper.dart';

void main() {
  group('mapToAppException', () {
    test('returns AppException as-is', () {
      const exception = StorageException(message: 'test');
      final result = mapToAppException(exception);
      expect(result, same(exception));
    });

    test('maps DioException 401 to AuthException', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final result = mapToAppException(dioError);
      expect(result, isA<AuthException>());
      expect((result as AuthException).statusCode, 401);
    });

    test('maps DioException 403 to AuthException', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 403,
        ),
      );
      final result = mapToAppException(dioError);
      expect(result, isA<AuthException>());
    });

    test('maps DioException timeout to NetworkException', () {
      final dioError = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final result = mapToAppException(dioError);
      expect(result, isA<NetworkException>());
      expect(result.message, contains('timed out'));
    });

    test('maps unknown error to UnknownException', () {
      final result = mapToAppException(Exception('something'));
      expect(result, isA<UnknownException>());
    });
  });
}
