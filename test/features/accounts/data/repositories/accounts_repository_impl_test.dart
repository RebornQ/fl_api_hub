import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_all_api_hub/core/error/app_exception.dart';
import 'package:fl_all_api_hub/core/network/site_type.dart';
import 'package:fl_all_api_hub/core/result/result.dart';
import 'package:fl_all_api_hub/features/accounts/data/datasources/accounts_local_datasource.dart';
import 'package:fl_all_api_hub/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:fl_all_api_hub/features/accounts/domain/entities/account.dart';

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
      test('returns Success with created account carrying the token', () async {
        when(() => mockLocal.save(any())).thenAnswer((_) async {});

        final accountWithToken = testAccount.copyWith(accessToken: 'token-123');
        final result = await repository.create(accountWithToken);

        expect(result, isA<Success<Account>>());
        expect((result as Success<Account>).data, accountWithToken);
        verify(() => mockLocal.save(accountWithToken)).called(1);
      });

      test('returns Success without access token on the entity', () async {
        when(() => mockLocal.save(any())).thenAnswer((_) async {});

        final result = await repository.create(testAccount);

        expect(result, isA<Success<Account>>());
        verify(() => mockLocal.save(testAccount)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.save(any())).thenThrow(Exception('save failed'));

        final result = await repository.create(testAccount);

        expect(result, isA<Failure<Account>>());
        expect((result as Failure<Account>).exception, isA<StorageException>());
      });
    });

    group('update', () {
      test('returns Success with updated account carrying the token', () async {
        when(() => mockLocal.save(any())).thenAnswer((_) async {});

        final accountWithToken = testAccount.copyWith(accessToken: 'new-token');
        final result = await repository.update(accountWithToken);

        expect(result, isA<Success<Account>>());
        expect((result as Success<Account>).data, accountWithToken);
        verify(() => mockLocal.save(accountWithToken)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.save(any())).thenThrow(Exception('update failed'));

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

    group('removeTagFromAllAccounts', () {
      test(
        'updates only accounts that reference the tag and returns the count',
        () async {
          final withTag = testAccount.copyWith(
            id: 'acc-with-tag',
            tagIds: ['keep-me', 'target-tag'],
          );
          final withoutTag = testAccount.copyWith(
            id: 'acc-clean',
            tagIds: ['keep-me'],
          );
          when(() => mockLocal.getAll()).thenReturn([withTag, withoutTag]);
          when(() => mockLocal.save(any())).thenAnswer((_) async {});

          final result = await repository.removeTagFromAllAccounts(
            'target-tag',
          );

          expect(result, isA<Success<int>>());
          expect((result as Success<int>).data, 1);
          verify(
            () => mockLocal.save(
              any(
                that: isA<Account>()
                    .having((a) => a.id, 'id', 'acc-with-tag')
                    .having((a) => a.tagIds, 'tagIds', ['keep-me']),
              ),
            ),
          ).called(1);
          verifyNever(
            () => mockLocal.save(
              any(that: isA<Account>().having((a) => a.id, 'id', 'acc-clean')),
            ),
          );
        },
      );

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.getAll()).thenThrow(Exception('read failed'));

        final result = await repository.removeTagFromAllAccounts('x');

        expect(result, isA<Failure<int>>());
        expect((result as Failure<int>).exception, isA<StorageException>());
      });
    });
  });
}
