import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import 'package:fl_api_hub/core/error/app_exception.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:fl_api_hub/features/tags/data/datasources/tags_local_datasource.dart';
import 'package:fl_api_hub/features/tags/data/repositories/tags_repository_impl.dart';
import 'package:fl_api_hub/features/tags/domain/entities/tag.dart';

class MockTagsLocalDataSource extends Mock implements TagsLocalDataSource {}

class MockAccountsRepository extends Mock implements AccountsRepository {}

/// Mocktail-based [Uuid] mock that returns a deterministic, monotonically
/// increasing id on each call to [Uuid.v4]. Only [v4] is stubbed because
/// that's all the production code calls — any other method falls through
/// to [Mock]'s default [noSuchMethod] handler.
class MockUuid extends Mock implements Uuid {}

Uuid _sequentialUuid() {
  final uuid = MockUuid();
  var counter = 0;
  when(() => uuid.v4()).thenAnswer((_) => 'v4-${++counter}');
  return uuid;
}

/// In-memory fake replacement for the Hive-backed data source.
class FakeTagsLocalDataSource implements TagsLocalDataSource {
  final Map<String, Tag> _store = {};

  @override
  List<Tag> getAll() => _store.values.toList(growable: false);

  @override
  Tag? getById(String id) => _store[id];

  @override
  Future<void> save(Tag tag) async {
    _store[tag.id] = tag;
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
  }
}

void main() {
  late FakeTagsLocalDataSource localDs;
  late MockAccountsRepository accountsRepo;
  late TagsRepositoryImpl repo;

  final dummyAccount = Account(
    id: 'acc-1',
    name: 'Dummy',
    baseUrl: 'https://example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(dummyAccount);
  });

  setUp(() {
    localDs = FakeTagsLocalDataSource();
    accountsRepo = MockAccountsRepository();
    repo = TagsRepositoryImpl(localDs, accountsRepo, uuid: _sequentialUuid());

    when(
      () => accountsRepo.removeTagFromAllAccounts(any()),
    ).thenAnswer((_) async => const Success(0));
  });

  group('upsertByName', () {
    test('creates a tag when none matches the normalized key', () async {
      final result = await repo.upsertByName('  Production  ');
      expect(result, isA<Success<Tag>>());
      final tag = (result as Success<Tag>).data;
      expect(tag.name, 'Production'); // Trimmed but original casing preserved.
      expect(localDs.getAll(), hasLength(1));
    });

    test('returns the existing tag when the normalized key matches', () async {
      final first = await repo.upsertByName('Prod');
      final second = await repo.upsertByName('  PROD ');
      expect(first, isA<Success<Tag>>());
      expect(second, isA<Success<Tag>>());
      expect(
        (first as Success<Tag>).data.id,
        equals((second as Success<Tag>).data.id),
      );
      expect(localDs.getAll(), hasLength(1));
    });

    test('rejects empty names with ValidationException', () async {
      final result = await repo.upsertByName('   ');
      expect(result, isA<Failure<Tag>>());
      expect((result as Failure<Tag>).exception, isA<ValidationException>());
    });
  });

  group('rename', () {
    test('renames an existing tag', () async {
      final created = await repo.upsertByName('Prod');
      final id = (created as Success<Tag>).data.id;

      final renamed = await repo.rename(id, 'Production');
      expect(renamed, isA<Success<Tag>>());
      final renamedTag = (renamed as Success<Tag>).data;
      expect(renamedTag.id, id); // id preserved
      expect(renamedTag.name, 'Production');
    });

    test('refuses to collide with a different existing tag', () async {
      final prod = await repo.upsertByName('Prod');
      await repo.upsertByName('Staging');

      final result = await repo.rename(
        (prod as Success<Tag>).data.id,
        'staging',
      );
      expect(result, isA<Failure<Tag>>());
      expect((result as Failure<Tag>).exception, isA<ValidationException>());
    });

    test('allows renaming with only casing changes', () async {
      final prod = await repo.upsertByName('prod');
      final result = await repo.rename((prod as Success<Tag>).data.id, 'PROD');
      expect(result, isA<Success<Tag>>());
      expect((result as Success<Tag>).data.name, 'PROD');
    });

    test('fails when the target id does not exist', () async {
      final result = await repo.rename('missing', 'Anything');
      expect(result, isA<Failure<Tag>>());
      expect((result as Failure<Tag>).exception, isA<StorageException>());
    });

    test('rejects empty names', () async {
      final prod = await repo.upsertByName('Prod');
      final result = await repo.rename((prod as Success<Tag>).data.id, '   ');
      expect(result, isA<Failure<Tag>>());
      expect((result as Failure<Tag>).exception, isA<ValidationException>());
    });
  });

  group('delete', () {
    test('cascades into accounts repository before removing the tag', () async {
      final created = await repo.upsertByName('Prod');
      final id = (created as Success<Tag>).data.id;

      final result = await repo.delete(id);
      expect(result, isA<Success<void>>());
      verify(() => accountsRepo.removeTagFromAllAccounts(id)).called(1);
      expect(localDs.getById(id), isNull);
    });

    test('fails when the tag does not exist', () async {
      final result = await repo.delete('missing');
      expect(result, isA<Failure<void>>());
      verifyNever(() => accountsRepo.removeTagFromAllAccounts(any()));
    });

    test('does not delete when cascade fails', () async {
      final created = await repo.upsertByName('Prod');
      final id = (created as Success<Tag>).data.id;

      when(() => accountsRepo.removeTagFromAllAccounts(id)).thenAnswer(
        (_) async => const Failure(StorageException(message: 'cascade failed')),
      );

      final result = await repo.delete(id);
      expect(result, isA<Failure<void>>());
      // Tag must still be present because we aborted early.
      expect(localDs.getById(id), isNotNull);
    });
  });

  group('getAll / getById', () {
    test('returns an empty list when nothing is stored', () async {
      final result = await repo.getAll();
      expect(result, isA<Success<List<Tag>>>());
      expect((result as Success<List<Tag>>).data, isEmpty);
    });

    test('returns Failure when id not found', () async {
      final result = await repo.getById('missing');
      expect(result, isA<Failure<Tag>>());
      expect((result as Failure<Tag>).exception, isA<StorageException>());
    });
  });
}
