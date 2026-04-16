import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/error/app_exception.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/accounts/data/datasources/accounts_local_datasource.dart';
import 'package:all_api_hub_flutter/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';

class MockAccountsLocalDataSource extends Mock
    implements AccountsLocalDataSource {}

void main() {
  late MockAccountsLocalDataSource mockLocal;
  late AccountsRepositoryImpl repository;

  final testAccount = Account(
    id: 'test-id',
    name: 'Test Account',
    baseUrl: 'https://api.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(testAccount);
  });

  setUp(() {
    mockLocal = MockAccountsLocalDataSource();
    repository = AccountsRepositoryImpl(mockLocal);
  });

  group('AccountsRepositoryImpl', () {
    group('getAll', () {
      test('returns Success with account list', () async {
        when(() => mockLocal.getAll()).thenReturn([testAccount]);

        final result = await repository.getAll();

        expect(result, isA<Success<List<Account>>>());
        expect((result as Success<List<Account>>).data, [testAccount]);
        verify(() => mockLocal.getAll()).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.getAll()).thenThrow(Exception('db error'));

        final result = await repository.getAll();

        expect(result, isA<Failure<List<Account>>>());
        expect(
          (result as Failure<List<Account>>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getById', () {
      test('returns Success when account is found', () async {
        when(() => mockLocal.getById('test-id')).thenReturn(testAccount);

        final result = await repository.getById('test-id');

        expect(result, isA<Success<Account>>());
        expect((result as Success<Account>).data, testAccount);
        verify(() => mockLocal.getById('test-id')).called(1);
      });

      test('returns Failure with Account not found when null', () async {
        when(() => mockLocal.getById('missing-id')).thenReturn(null);

        final result = await repository.getById('missing-id');

        expect(result, isA<Failure<Account>>());
        final failure = result as Failure<Account>;
        expect(failure.exception, isA<StorageException>());
        expect(failure.exception.message, contains('Account not found'));
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getById('test-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getById('test-id');

        expect(result, isA<Failure<Account>>());
        expect((result as Failure<Account>).exception, isA<StorageException>());
      });
    });

    group('create', () {
      test('returns Success with created account', () async {
        when(
          () => mockLocal.save(any(), accessToken: any(named: 'accessToken')),
        ).thenAnswer((_) async {});

        final result = await repository.create(
          testAccount,
          accessToken: 'token-123',
        );

        expect(result, isA<Success<Account>>());
        expect((result as Success<Account>).data, testAccount);
        verify(
          () => mockLocal.save(testAccount, accessToken: 'token-123'),
        ).called(1);
      });

      test('returns Success without accessToken', () async {
        when(
          () => mockLocal.save(any(), accessToken: any(named: 'accessToken')),
        ).thenAnswer((_) async {});

        final result = await repository.create(testAccount);

        expect(result, isA<Success<Account>>());
        verify(() => mockLocal.save(testAccount, accessToken: null)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.save(any(), accessToken: any(named: 'accessToken')),
        ).thenThrow(Exception('save failed'));

        final result = await repository.create(testAccount);

        expect(result, isA<Failure<Account>>());
        expect((result as Failure<Account>).exception, isA<StorageException>());
      });
    });

    group('update', () {
      test('returns Success with updated account', () async {
        when(
          () => mockLocal.save(any(), accessToken: any(named: 'accessToken')),
        ).thenAnswer((_) async {});

        final result = await repository.update(
          testAccount,
          accessToken: 'new-token',
        );

        expect(result, isA<Success<Account>>());
        expect((result as Success<Account>).data, testAccount);
        verify(
          () => mockLocal.save(testAccount, accessToken: 'new-token'),
        ).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.save(any(), accessToken: any(named: 'accessToken')),
        ).thenThrow(Exception('update failed'));

        final result = await repository.update(testAccount);

        expect(result, isA<Failure<Account>>());
        expect((result as Failure<Account>).exception, isA<StorageException>());
      });
    });

    group('delete', () {
      test('returns Success with null', () async {
        when(() => mockLocal.delete('test-id')).thenAnswer((_) async {});

        final result = await repository.delete('test-id');

        expect(result, isA<Success<void>>());
        verify(() => mockLocal.delete('test-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.delete('test-id'),
        ).thenThrow(Exception('delete failed'));

        final result = await repository.delete('test-id');

        expect(result, isA<Failure<void>>());
        expect((result as Failure<void>).exception, isA<StorageException>());
      });
    });

    group('getAccessToken', () {
      test('returns Success with token', () async {
        when(
          () => mockLocal.getAccessToken('test-id'),
        ).thenAnswer((_) async => 'stored-token');

        final result = await repository.getAccessToken('test-id');

        expect(result, isA<Success<String?>>());
        expect((result as Success<String?>).data, 'stored-token');
        verify(() => mockLocal.getAccessToken('test-id')).called(1);
      });

      test('returns Success with null when no token', () async {
        when(
          () => mockLocal.getAccessToken('test-id'),
        ).thenAnswer((_) async => null);

        final result = await repository.getAccessToken('test-id');

        expect(result, isA<Success<String?>>());
        expect((result as Success<String?>).data, isNull);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getAccessToken('test-id'),
        ).thenThrow(Exception('read failed'));

        final result = await repository.getAccessToken('test-id');

        expect(result, isA<Failure<String?>>());
        expect((result as Failure<String?>).exception, isA<StorageException>());
      });
    });
  });
}
