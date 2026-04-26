import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/error/app_exception.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/keys/data/datasources/keys_local_datasource.dart';
import 'package:fl_api_hub/features/keys/data/repositories/keys_repository_impl.dart';
import 'package:fl_api_hub/features/keys/domain/entities/api_key.dart';

class MockKeysLocalDataSource extends Mock implements KeysLocalDataSource {}

void main() {
  late MockKeysLocalDataSource mockLocal;
  late KeysRepositoryImpl repository;

  final testApiKey = ApiKey(
    id: 'key-id',
    accountId: 'account-id',
    name: 'Test Key',
    quota: 1000,
    usedQuota: 200,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(testApiKey);
  });

  setUp(() {
    mockLocal = MockKeysLocalDataSource();
    repository = KeysRepositoryImpl.localOnly(mockLocal);
  });

  group('KeysRepositoryImpl', () {
    group('getByAccountId', () {
      test('returns Success with api key list', () async {
        when(
          () => mockLocal.getByAccountId('account-id'),
        ).thenReturn([testApiKey]);

        final result = await repository.getByAccountId('account-id');

        expect(result, isA<Success<List<ApiKey>>>());
        expect((result as Success<List<ApiKey>>).data, [testApiKey]);
        verify(() => mockLocal.getByAccountId('account-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getByAccountId('account-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getByAccountId('account-id');

        expect(result, isA<Failure<List<ApiKey>>>());
        expect(
          (result as Failure<List<ApiKey>>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getById', () {
      test('returns Success when api key is found', () async {
        when(() => mockLocal.getById('key-id')).thenReturn(testApiKey);

        final result = await repository.getById('key-id');

        expect(result, isA<Success<ApiKey>>());
        expect((result as Success<ApiKey>).data, testApiKey);
        verify(() => mockLocal.getById('key-id')).called(1);
      });

      test('returns Failure with API key not found when null', () async {
        when(() => mockLocal.getById('missing-id')).thenReturn(null);

        final result = await repository.getById('missing-id');

        expect(result, isA<Failure<ApiKey>>());
        final failure = result as Failure<ApiKey>;
        expect(failure.exception, isA<StorageException>());
        expect(failure.exception.message, contains('API key not found'));
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getById('key-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getById('key-id');

        expect(result, isA<Failure<ApiKey>>());
        expect((result as Failure<ApiKey>).exception, isA<StorageException>());
      });
    });

    group('create', () {
      test(
        'returns Success with created api key carrying the secret',
        () async {
          when(() => mockLocal.save(any())).thenAnswer((_) async {});

          final keyWithSecret = testApiKey.copyWith(
            keyValue: 'sk-secret-value',
          );
          final result = await repository.create(keyWithSecret);

          expect(result, isA<Success<ApiKey>>());
          expect((result as Success<ApiKey>).data, keyWithSecret);
          verify(() => mockLocal.save(keyWithSecret)).called(1);
        },
      );

      test('returns Success without secret on the entity', () async {
        when(() => mockLocal.save(any())).thenAnswer((_) async {});

        final result = await repository.create(testApiKey);

        expect(result, isA<Success<ApiKey>>());
        verify(() => mockLocal.save(testApiKey)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.save(any())).thenThrow(Exception('save failed'));

        final result = await repository.create(testApiKey);

        expect(result, isA<Failure<ApiKey>>());
        expect((result as Failure<ApiKey>).exception, isA<StorageException>());
      });
    });

    group('update', () {
      test(
        'returns Success with updated api key carrying the secret',
        () async {
          when(() => mockLocal.save(any())).thenAnswer((_) async {});

          final keyWithSecret = testApiKey.copyWith(keyValue: 'new-secret');
          final result = await repository.update(keyWithSecret);

          expect(result, isA<Success<ApiKey>>());
          expect((result as Success<ApiKey>).data, keyWithSecret);
          verify(() => mockLocal.save(keyWithSecret)).called(1);
        },
      );

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.save(any())).thenThrow(Exception('update failed'));

        final result = await repository.update(testApiKey);

        expect(result, isA<Failure<ApiKey>>());
        expect((result as Failure<ApiKey>).exception, isA<StorageException>());
      });
    });

    group('delete', () {
      test('returns Success with null', () async {
        when(() => mockLocal.delete('key-id')).thenAnswer((_) async {});

        final result = await repository.delete('key-id');

        expect(result, isA<Success<void>>());
        verify(() => mockLocal.delete('key-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.delete('key-id'),
        ).thenThrow(Exception('delete failed'));

        final result = await repository.delete('key-id');

        expect(result, isA<Failure<void>>());
        expect((result as Failure<void>).exception, isA<StorageException>());
      });
    });
  });
}
