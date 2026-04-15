import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/error/app_exception.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';

void main() {
  group('Result', () {
    test('Success carries data', () {
      const result = Success<int>(42);
      expect(result.data, 42);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 42);
    });

    test('Failure carries exception', () {
      const result = Failure<int>(NetworkException(message: 'timeout'));
      expect(result.exception, isA<NetworkException>());
      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
    });

    test('when() dispatches to correct branch', () {
      const success = Success<String>('hello');
      const failure = Failure<String>(StorageException(message: 'disk full'));

      expect(
        success.when(onSuccess: (d) => 'ok:$d', onFailure: (_) => 'err'),
        'ok:hello',
      );
      expect(
        failure.when(
          onSuccess: (d) => 'ok:$d',
          onFailure: (e) => 'err:${e.message}',
        ),
        'err:disk full',
      );
    });

    test('getOrDefault returns data on success', () {
      const result = Success<int>(7);
      expect(result.getOrDefault(0), 7);
    });

    test('getOrDefault returns default on failure', () {
      const result = Failure<int>(UnknownException(message: 'oops'));
      expect(result.getOrDefault(99), 99);
    });
  });
}
