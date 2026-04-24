/// Unit tests for [AccountCheckInHistoryNotifier].
///
/// Covers:
/// - The `build` first-page behavior (full page / short page / empty).
/// - The `loadMore` paging + termination + idempotency.
/// - The `clearAll` flow (repo delete call, state reset, downstream
///   provider invalidation).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/error/app_exception.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/check_in_result.dart';
import 'package:fl_api_hub/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:fl_api_hub/features/check_in/presentation/providers/check_in_providers.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

/// Produces [count] deterministic [CheckInResult]s with stable ids, all
/// pointing at [accountId]. The first result is the newest (i == 0).
List<CheckInResult> _results({
  required String accountId,
  required int count,
  String prefix = 'r',
  CheckInStatus status = CheckInStatus.success,
}) {
  final base = DateTime(2026, 4, 22, 10, 0);
  return List.generate(count, (i) {
    return CheckInResult(
      id: '$prefix-$i',
      taskId: 'task-$accountId',
      accountId: accountId,
      status: status,
      message: 'msg $i',
      executedAt: base.subtract(Duration(minutes: i)),
    );
  });
}

void main() {
  late _MockCheckInRepository repo;
  const accountId = 'acc-1';

  setUpAll(() {
    registerFallbackValue(
      CheckInResult(
        id: 'fallback',
        taskId: 'fallback',
        accountId: 'fallback',
        status: CheckInStatus.skipped,
        executedAt: DateTime(2026, 4, 22),
      ),
    );
  });

  setUp(() {
    repo = _MockCheckInRepository();
  });

  /// Builds a [ProviderContainer] with the mocked repository wired in.
  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [checkInRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build — first page', () {
    test('full first page → hasMore true, nextOffset == pageSize', () async {
      final fullPage = _results(accountId: accountId, count: 20);
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer((_) async => Success(fullPage));

      final container = buildContainer();
      final state = await container.read(
        accountCheckInHistoryProvider(accountId).future,
      );

      expect(state.items, hasLength(20));
      expect(state.hasMore, isTrue);
      expect(state.nextOffset, 20);
      expect(state.isLoadingMore, isFalse);
      verify(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).called(1);
    });

    test(
      'short first page → hasMore false, nextOffset == items.length',
      () async {
        final shortPage = _results(accountId: accountId, count: 7);
        when(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 0,
          ),
        ).thenAnswer((_) async => Success(shortPage));

        final container = buildContainer();
        final state = await container.read(
          accountCheckInHistoryProvider(accountId).future,
        );

        expect(state.items, hasLength(7));
        expect(state.hasMore, isFalse);
        expect(state.nextOffset, 7);
      },
    );

    test('empty first page → items empty, hasMore false, offset 0', () async {
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));

      final container = buildContainer();
      final state = await container.read(
        accountCheckInHistoryProvider(accountId).future,
      );

      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.nextOffset, 0);
    });

    test('Failure result → empty items with hasMore false', () async {
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer(
        (_) async => const Failure(StorageException(message: 'boom')),
      );

      final container = buildContainer();
      final state = await container.read(
        accountCheckInHistoryProvider(accountId).future,
      );

      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
      expect(state.nextOffset, 0);
    });
  });

  group('loadMore', () {
    test('appends full second page and keeps paging on', () async {
      final page1 = _results(accountId: accountId, count: 20, prefix: 'p1');
      final page2 = _results(accountId: accountId, count: 20, prefix: 'p2');
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer((_) async => Success(page1));
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 20,
        ),
      ).thenAnswer((_) async => Success(page2));

      final container = buildContainer();
      await container.read(accountCheckInHistoryProvider(accountId).future);
      await container
          .read(accountCheckInHistoryProvider(accountId).notifier)
          .loadMore();

      final state = container
          .read(accountCheckInHistoryProvider(accountId))
          .requireValue;
      expect(state.items, hasLength(40));
      expect(state.nextOffset, 40);
      expect(
        state.hasMore,
        isTrue,
        reason: 'A full page came back → there may still be more.',
      );
    });

    test('short second page flips hasMore to false', () async {
      final page1 = _results(accountId: accountId, count: 20, prefix: 'p1');
      final page2 = _results(accountId: accountId, count: 5, prefix: 'p2');
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer((_) async => Success(page1));
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 20,
        ),
      ).thenAnswer((_) async => Success(page2));

      final container = buildContainer();
      await container.read(accountCheckInHistoryProvider(accountId).future);
      await container
          .read(accountCheckInHistoryProvider(accountId).notifier)
          .loadMore();

      final state = container
          .read(accountCheckInHistoryProvider(accountId))
          .requireValue;
      expect(state.items, hasLength(25));
      expect(state.nextOffset, 25);
      expect(state.hasMore, isFalse);
    });

    test('no-op when hasMore is already false', () async {
      final shortPage = _results(accountId: accountId, count: 3);
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 0,
        ),
      ).thenAnswer((_) async => Success(shortPage));

      final container = buildContainer();
      await container.read(accountCheckInHistoryProvider(accountId).future);

      // After the short initial page, hasMore is false. Calling loadMore
      // should not result in any additional repo calls.
      await container
          .read(accountCheckInHistoryProvider(accountId).notifier)
          .loadMore();
      await container
          .read(accountCheckInHistoryProvider(accountId).notifier)
          .loadMore();

      verify(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: any(named: 'offset'),
        ),
      ).called(1);
    });

    test(
      'concurrent loadMore calls collapse into a single repo call',
      () async {
        final page1 = _results(accountId: accountId, count: 20, prefix: 'p1');
        final page2 = _results(accountId: accountId, count: 20, prefix: 'p2');

        when(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 0,
          ),
        ).thenAnswer((_) async => Success(page1));

        // Gate the second page so both loadMore invocations overlap while the
        // first is still in flight.
        final gate = Completer<void>();
        when(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 20,
          ),
        ).thenAnswer((_) async {
          await gate.future;
          return Success(page2);
        });

        final container = buildContainer();
        await container.read(accountCheckInHistoryProvider(accountId).future);

        final notifier = container.read(
          accountCheckInHistoryProvider(accountId).notifier,
        );
        final f1 = notifier.loadMore();
        final f2 = notifier.loadMore();

        // Allow the first (and only real) fetch to complete.
        gate.complete();
        await Future.wait([f1, f2]);

        // Initial build call (offset 0) must be present too; verify both and
        // then assert no additional calls were made.
        verify(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 0,
          ),
        ).called(1);
        verify(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 20,
          ),
        ).called(1);
        verifyNoMoreInteractions(repo);
      },
    );
  });

  group('clearAll', () {
    test(
      'calls deleteAllResultsByAccountId, resets state, and invalidates downstream providers',
      () async {
        final page1 = _results(accountId: accountId, count: 20);
        when(
          () => repo.getResultsByAccountIdPaged(
            accountId,
            limit: kCheckInDetailPageSize,
            offset: 0,
          ),
        ).thenAnswer((_) async => Success(page1));
        when(
          () => repo.deleteAllResultsByAccountId(accountId),
        ).thenAnswer((_) async => const Success<int>(20));
        when(
          () => repo.getLatestResultPerAccount(),
        ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));
        // Stats provider also depends on the paged fetch; stub it once more so
        // that when it is re-resolved after invalidation we don't blow up.
        when(
          () =>
              repo.getResultsByAccountIdPaged(accountId, limit: 50, offset: 0),
        ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));

        final container = buildContainer();

        // Prime both the history and the downstream providers so that
        // invalidation has an observable effect (next read triggers a fetch).
        await container.read(accountCheckInHistoryProvider(accountId).future);
        await container.read(latestResultPerAccountProvider.future);
        await container.read(accountCheckInStatsProvider(accountId).future);

        // Sanity check: getLatestResultPerAccount was called once during the
        // initial warm-up.
        verify(() => repo.getLatestResultPerAccount()).called(1);

        await container
            .read(accountCheckInHistoryProvider(accountId).notifier)
            .clearAll();

        // Repo delete call
        verify(() => repo.deleteAllResultsByAccountId(accountId)).called(1);

        // State was reset to empty.
        final state = container
            .read(accountCheckInHistoryProvider(accountId))
            .requireValue;
        expect(state.items, isEmpty);
        expect(state.hasMore, isFalse);
        expect(state.nextOffset, 0);

        // latestResultPerAccountProvider was invalidated → reading it again
        // triggers a second repo fetch.
        await container.read(latestResultPerAccountProvider.future);
        verify(() => repo.getLatestResultPerAccount()).called(1);

        // accountCheckInStatsProvider was invalidated → reading it again
        // triggers a second paged-50 fetch.
        await container.read(accountCheckInStatsProvider(accountId).future);
        verify(
          () =>
              repo.getResultsByAccountIdPaged(accountId, limit: 50, offset: 0),
        ).called(2);
      },
    );
  });
}
