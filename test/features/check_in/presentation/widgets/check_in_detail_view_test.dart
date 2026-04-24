/// Widget tests for [CheckInDetailView].
///
/// Covers the summary card + list + footer rendering paths, the
/// scroll-triggered `loadMore`, the clear-all confirmation dialog, and the
/// empty-state branch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/check_in_result.dart';
import 'package:fl_api_hub/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:fl_api_hub/features/check_in/presentation/providers/check_in_providers.dart';
import 'package:fl_api_hub/features/check_in/presentation/widgets/check_in_detail_view.dart';
import 'package:fl_api_hub/features/check_in/presentation/widgets/check_in_result_card.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

/// Serves a fixed account list so [accountsProvider] resolves without hitting
/// the Hive-backed implementation.
class _FakeAccountsNotifier extends AccountsNotifier {
  _FakeAccountsNotifier(this._initial);

  final List<Account> _initial;

  @override
  Future<List<Account>> build() async => _initial;

  @override
  Future<void> checkAll({bool force = false}) async {}

  @override
  Future<void> checkOne(String id) async {}
}

Account _account({required String id, required String name}) {
  return Account(
    id: id,
    name: name,
    baseUrl: 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: true,
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

List<CheckInResult> _results({
  required String accountId,
  required int count,
  String prefix = 'r',
}) {
  final base = DateTime(2026, 4, 22, 10, 0);
  return List.generate(count, (i) {
    return CheckInResult(
      id: '$prefix-$i',
      taskId: 'task-$accountId',
      accountId: accountId,
      status: CheckInStatus.success,
      message: 'msg $i',
      executedAt: base.subtract(Duration(minutes: i)),
    );
  });
}

void main() {
  late _MockCheckInRepository repo;

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

    // Default `latestResultPerAccountProvider` stub so the `ref.listen`
    // inside [CheckInDetailView] never explodes. Tests that need to assert
    // on this can re-stub.
    when(
      () => repo.getLatestResultPerAccount(),
    ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));
  });

  /// Stubs both the detail-view paged fetch and the stats card fetch (the
  /// stats provider always pulls offset:0 limit:50).
  void stubPages({
    required String accountId,
    required List<CheckInResult> firstPage,
    List<CheckInResult>? secondPage,
    List<CheckInResult>? statsOverride,
  }) {
    // Fallback: any unstubbed offset returns an empty page so the notifier
    // never crashes on an extra scroll-triggered `loadMore`.
    when(
      () => repo.getResultsByAccountIdPaged(
        accountId,
        limit: kCheckInDetailPageSize,
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));
    when(
      () => repo.getResultsByAccountIdPaged(
        accountId,
        limit: kCheckInDetailPageSize,
        offset: 0,
      ),
    ).thenAnswer((_) async => Success(firstPage));
    if (secondPage != null) {
      when(
        () => repo.getResultsByAccountIdPaged(
          accountId,
          limit: kCheckInDetailPageSize,
          offset: 20,
        ),
      ).thenAnswer((_) async => Success(secondPage));
    }
    when(
      () => repo.getResultsByAccountIdPaged(accountId, limit: 50, offset: 0),
    ).thenAnswer((_) async => Success(statsOverride ?? firstPage));
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required String accountId,
    required List<Account> accounts,
    VoidCallback? onCleared,
  }) async {
    final container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith(() => _FakeAccountsNotifier(accounts)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              // Generous size so the ListView lays out enough rows at once.
              width: 500,
              height: 800,
              child: CheckInDetailView(
                accountId: accountId,
                onCleared: onCleared,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'renders summary card, list rows and the "no more" footer when hasMore is false',
    (tester) async {
      const accountId = 'acc-1';
      stubPages(
        accountId: accountId,
        firstPage: _results(accountId: accountId, count: 5),
      );

      await pump(
        tester,
        accountId: accountId,
        accounts: [_account(id: accountId, name: 'Alpha')],
      );

      // Summary card headline — "共 N 条记录"
      expect(find.textContaining('共 5 条记录'), findsOneWidget);
      // ListView is lazy; assert on the builder's declared item count
      // (5 rows + summary header + footer = 7).
      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 7);
      // At least one result card is actually laid out.
      expect(find.byType(CheckInResultCard), findsWidgets);
      // Scroll to the bottom to reveal the footer sentinel.
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('— 没有更多 —'), findsOneWidget);
    },
  );

  testWidgets('scrolling triggers loadMore with offset 20', (tester) async {
    const accountId = 'acc-2';
    final page1 = _results(accountId: accountId, count: 20, prefix: 'p1');
    final page2 = _results(accountId: accountId, count: 20, prefix: 'p2');
    stubPages(
      accountId: accountId,
      firstPage: page1,
      secondPage: page2,
      statsOverride: page1,
    );

    await pump(
      tester,
      accountId: accountId,
      accounts: [_account(id: accountId, name: 'Bravo')],
    );

    // No offset:20 call yet.
    verifyNever(
      () => repo.getResultsByAccountIdPaged(
        accountId,
        limit: kCheckInDetailPageSize,
        offset: 20,
      ),
    );

    // Drag the list up repeatedly until the bottom is near.
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);

    // Enough drag distance to cross the 200px loadMore threshold regardless
    // of individual row height.
    for (var i = 0; i < 10; i++) {
      await tester.drag(listFinder, const Offset(0, -500));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    verify(
      () => repo.getResultsByAccountIdPaged(
        accountId,
        limit: kCheckInDetailPageSize,
        offset: 20,
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets(
    'tapping the clear icon opens a confirm dialog; confirming clears + fires callback',
    (tester) async {
      const accountId = 'acc-3';
      stubPages(
        accountId: accountId,
        firstPage: _results(accountId: accountId, count: 3),
      );
      when(
        () => repo.deleteAllResultsByAccountId(accountId),
      ).thenAnswer((_) async => const Success<int>(3));

      var onClearedCalled = false;
      await pump(
        tester,
        accountId: accountId,
        accounts: [_account(id: accountId, name: 'Charlie')],
        onCleared: () => onClearedCalled = true,
      );

      // Header-row clear icon.
      final clearIcon = find.byIcon(Icons.delete_sweep_outlined);
      expect(clearIcon, findsOneWidget);
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      // Dialog copy.
      expect(find.text('清空签到记录'), findsOneWidget);
      expect(find.textContaining('确定清空 Charlie'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('清空'), findsOneWidget);

      // Confirm.
      await tester.tap(find.widgetWithText(FilledButton, '清空'));
      await tester.pumpAndSettle();

      verify(() => repo.deleteAllResultsByAccountId(accountId)).called(1);
      expect(onClearedCalled, isTrue);
    },
  );

  testWidgets('empty state rendered when the account has no records', (
    tester,
  ) async {
    const accountId = 'acc-4';
    stubPages(
      accountId: accountId,
      firstPage: const [],
      statsOverride: const [],
    );

    await pump(
      tester,
      accountId: accountId,
      accounts: [_account(id: accountId, name: 'Delta')],
    );

    expect(find.text('该账号暂无签到记录'), findsOneWidget);
    // Summary card is still rendered.
    expect(find.textContaining('共 0 条记录'), findsOneWidget);
    // No list rows in empty state.
    expect(find.byType(CheckInResultCard), findsNothing);
  });
}
