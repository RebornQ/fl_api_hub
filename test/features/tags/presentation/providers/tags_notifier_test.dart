import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/error/app_exception.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/domain/repositories/account_reachability_repository.dart';
import 'package:fl_api_hub/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/account_reachability_providers.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/core/network/reachability_status.dart';
import 'package:fl_api_hub/features/tags/domain/entities/tag.dart';
import 'package:fl_api_hub/features/tags/domain/repositories/tags_repository.dart';
import 'package:fl_api_hub/features/tags/presentation/providers/tags_providers.dart';

class MockTagsRepository extends Mock implements TagsRepository {}

class MockAccountsRepository extends Mock implements AccountsRepository {}

class FakeAccountReachabilityRepository
    implements AccountReachabilityRepository {
  final Map<String, ReachabilityRecord> _store = {};

  @override
  Map<String, ReachabilityRecord> getAll() => Map.of(_store);

  @override
  Future<void> put(String accountId, ReachabilityRecord record) async {
    _store[accountId] = record;
  }

  @override
  Future<void> remove(String accountId) async {
    _store.remove(accountId);
  }
}

Tag _tag(String id, String name, {DateTime? createdAt, DateTime? updatedAt}) {
  final now = DateTime(2026, 1, 1);
  return Tag(
    id: id,
    name: name,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  late MockTagsRepository mockTagsRepo;
  late MockAccountsRepository mockAccountsRepo;
  late FakeAccountReachabilityRepository fakeReachability;
  late ProviderContainer container;

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
    mockTagsRepo = MockTagsRepository();
    mockAccountsRepo = MockAccountsRepository();
    fakeReachability = FakeAccountReachabilityRepository();

    when(
      () => mockAccountsRepo.getAll(),
    ).thenAnswer((_) async => const Success([]));
  });

  tearDown(() {
    container.dispose();
  });

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        tagsRepositoryProvider.overrideWithValue(mockTagsRepo),
        accountsRepositoryProvider.overrideWithValue(mockAccountsRepo),
        accountReachabilityRepositoryProvider.overrideWithValue(
          fakeReachability,
        ),
      ],
    );
  }

  group('TagsNotifier.build', () {
    test('loads tags from repository', () async {
      when(() => mockTagsRepo.getAll()).thenAnswer(
        (_) async => Success([_tag('t-1', 'Prod'), _tag('t-2', 'Staging')]),
      );

      container = buildContainer();
      final tags = await container.read(tagsProvider.future);
      expect(tags.map((t) => t.id), ['t-1', 't-2']);
    });

    test('surfaces AsyncError on repository failure', () async {
      when(() => mockTagsRepo.getAll()).thenAnswer(
        (_) async => const Failure(StorageException(message: 'load failed')),
      );

      container = buildContainer();
      final state = container.read(tagsProvider);
      await expectLater(
        container.read(tagsProvider.future),
        throwsA(isA<StorageException>()),
      );
      expect(state.isLoading, isTrue);
    });
  });

  group('TagsNotifier.upsertByName', () {
    test('concurrent upserts with same name return the same id', () async {
      var counter = 0;
      Tag? cached;

      // Simulate the repo: first call creates, subsequent calls return the
      // already-created tag. Each invocation yields to the event loop so
      // both callers really are in-flight before the first one finishes.
      when(() => mockTagsRepo.upsertByName(any())).thenAnswer((_) async {
        await Future<void>.delayed(Duration.zero);
        if (cached == null) {
          counter++;
          cached = _tag('t-created', 'Prod');
        }
        return Success(cached!);
      });
      when(
        () => mockTagsRepo.getAll(),
      ).thenAnswer((_) async => const Success([]));

      container = buildContainer();
      await container.read(tagsProvider.future); // prime the notifier

      final notifier = container.read(tagsProvider.notifier);
      final results = await Future.wait([
        notifier.upsertByName('Prod'),
        notifier.upsertByName('prod'),
      ]);

      expect(results.map((t) => t.id).toSet(), {'t-created'});
      expect(counter, 1);
      // Both calls should have been dispatched to the repo because the
      // notifier cannot know whether a previous call succeeded.
      verify(() => mockTagsRepo.upsertByName(any())).called(2);
    });

    test('throws the repository exception on failure', () async {
      when(
        () => mockTagsRepo.getAll(),
      ).thenAnswer((_) async => const Success([]));
      when(() => mockTagsRepo.upsertByName(any())).thenAnswer(
        (_) async => const Failure(ValidationException(message: 'empty name')),
      );

      container = buildContainer();
      await container.read(tagsProvider.future);

      final notifier = container.read(tagsProvider.notifier);
      await expectLater(
        notifier.upsertByName(' '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('successful upsert merges the tag into state', () async {
      when(
        () => mockTagsRepo.getAll(),
      ).thenAnswer((_) async => const Success([]));
      when(
        () => mockTagsRepo.upsertByName(any()),
      ).thenAnswer((_) async => Success(_tag('t-1', 'Prod')));

      container = buildContainer();
      await container.read(tagsProvider.future);

      final notifier = container.read(tagsProvider.notifier);
      await notifier.upsertByName('Prod');
      final tags = container.read(tagsProvider).value;
      expect(tags, isNotNull);
      expect(tags!.single.name, 'Prod');
    });
  });

  group('TagsNotifier.delete', () {
    test('removes tag from state and invalidates accountsProvider', () async {
      when(() => mockTagsRepo.getAll()).thenAnswer(
        (_) async => Success([_tag('t-1', 'Prod'), _tag('t-2', 'Staging')]),
      );
      when(
        () => mockTagsRepo.delete('t-1'),
      ).thenAnswer((_) async => const Success(null));

      container = buildContainer();
      await container.read(tagsProvider.future);

      // Prime accountsProvider so we can observe an invalidate triggering a
      // rebuild. Consume any pending getAll invocations captured during the
      // priming so the second verify only picks up new calls.
      await container.read(accountsProvider.future);
      verify(() => mockAccountsRepo.getAll()).called(greaterThanOrEqualTo(1));

      final notifier = container.read(tagsProvider.notifier);
      await notifier.delete('t-1');

      // After delete we expect accountsProvider to be invalidated — which
      // causes its AsyncNotifier.build() to be re-run on next read.
      await container.read(accountsProvider.future);
      verify(() => mockAccountsRepo.getAll()).called(greaterThanOrEqualTo(1));

      final tags = container.read(tagsProvider).value!;
      expect(tags.map((t) => t.id), ['t-2']);
    });

    test('propagates repository failure without touching state', () async {
      when(
        () => mockTagsRepo.getAll(),
      ).thenAnswer((_) async => Success([_tag('t-1', 'Prod')]));
      when(() => mockTagsRepo.delete('t-1')).thenAnswer(
        (_) async => const Failure(StorageException(message: 'cascade failed')),
      );

      container = buildContainer();
      await container.read(tagsProvider.future);
      final notifier = container.read(tagsProvider.notifier);

      await expectLater(
        notifier.delete('t-1'),
        throwsA(isA<StorageException>()),
      );
      final tags = container.read(tagsProvider).value!;
      expect(tags.map((t) => t.id), ['t-1']);
    });
  });

  group('TagsNotifier.rename', () {
    test('replaces the tag in state', () async {
      when(
        () => mockTagsRepo.getAll(),
      ).thenAnswer((_) async => Success([_tag('t-1', 'Prod')]));
      when(
        () => mockTagsRepo.rename('t-1', 'Production'),
      ).thenAnswer((_) async => Success(_tag('t-1', 'Production')));

      container = buildContainer();
      await container.read(tagsProvider.future);

      final notifier = container.read(tagsProvider.notifier);
      await notifier.rename('t-1', 'Production');
      final tag = container.read(tagsProvider).value!.single;
      expect(tag.id, 't-1');
      expect(tag.name, 'Production');
    });
  });
}
