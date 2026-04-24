import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/reachability_status.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/domain/repositories/account_reachability_repository.dart';
import 'package:fl_api_hub/features/accounts/presentation/pages/accounts_page.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/account_reachability_providers.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_filter_providers.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/features/accounts/presentation/widgets/account_card.dart';

/// In-memory fake so the page test doesn't need a Hive box to hydrate the
/// reachability map on first watch.
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

/// Serves a preconfigured account list without touching the repository and
/// no-ops every reachability scan so [AccountsPage.initState]'s post-frame
/// `checkAll()` invocation does not fan out.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this._initial);

  final List<Account> _initial;

  @override
  Future<List<Account>> build() async => _initial;

  @override
  Future<void> checkAll({bool force = false}) async {}

  @override
  Future<void> checkOne(String id) async {}
}

Account _account({
  required String id,
  required String name,
  String? baseUrl,
  String? notes,
  bool enabled = true,
}) {
  return Account(
    id: id,
    name: name,
    baseUrl: baseUrl ?? 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: enabled,
    notes: notes,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required List<Account> accounts,
}) async {
  final container = ProviderContainer(
    overrides: [
      accountsProvider.overrideWith(() => FakeAccountsNotifier(accounts)),
      accountReachabilityRepositoryProvider.overrideWithValue(
        FakeAccountReachabilityRepository(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AccountsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('AccountsPage ordering', () {
    testWidgets(
      'disabled accounts sink to the bottom while preserving input order',
      (tester) async {
        final accountA = _account(id: 'acc-a', name: 'Alpha', enabled: true);
        final accountB = _account(id: 'acc-b', name: 'Bravo', enabled: false);
        final accountC = _account(id: 'acc-c', name: 'Charlie', enabled: true);

        await _pumpPage(tester, accounts: [accountA, accountB, accountC]);

        final renderedCards = tester
            .widgetList<AccountCard>(find.byType(AccountCard))
            .toList();

        expect(renderedCards, hasLength(3));
        expect(
          renderedCards.map((c) => c.account.id).toList(),
          ['acc-a', 'acc-c', 'acc-b'],
          reason:
              'Enabled accounts [A, C] must render before the disabled one [B]',
        );
      },
    );
  });

  group('AccountsPage filter chips', () {
    testWidgets('chips display label with count', (tester) async {
      await _pumpPage(
        tester,
        accounts: [
          _account(id: 'a', name: 'A', enabled: true),
          _account(id: 'b', name: 'B', enabled: true),
          _account(id: 'c', name: 'C', enabled: false),
        ],
      );

      expect(find.text('全部 (3)'), findsOneWidget);
      expect(find.text('已启用 (2)'), findsOneWidget);
      expect(find.text('已禁用 (1)'), findsOneWidget);
    });

    testWidgets('removed legacy chips are no longer rendered', (tester) async {
      await _pumpPage(tester, accounts: []);
      expect(find.textContaining('已同步'), findsNothing);
      expect(find.textContaining('警告'), findsNothing);
    });

    testWidgets('tapping "已启用" narrows the list to enabled accounts only', (
      tester,
    ) async {
      final container = await _pumpPage(
        tester,
        accounts: [
          _account(id: 'a', name: 'A', enabled: true),
          _account(id: 'b', name: 'B', enabled: false),
          _account(id: 'c', name: 'C', enabled: true),
        ],
      );

      await tester.tap(find.text('已启用 (2)'));
      await tester.pumpAndSettle();

      expect(
        container.read(accountListFilterProvider),
        AccountListFilter.enabled,
      );
      final cards = tester
          .widgetList<AccountCard>(find.byType(AccountCard))
          .toList();
      expect(cards.map((c) => c.account.id).toList(), ['a', 'c']);
    });

    testWidgets('tapping the currently selected chip is a no-op', (
      tester,
    ) async {
      final container = await _pumpPage(
        tester,
        accounts: [_account(id: 'a', name: 'A', enabled: true)],
      );

      // Default is "全部". Tapping it again should not change state.
      expect(container.read(accountListFilterProvider), AccountListFilter.all);

      await tester.tap(find.text('全部 (1)'));
      await tester.pumpAndSettle();

      expect(
        container.read(accountListFilterProvider),
        AccountListFilter.all,
        reason: 'Strict Radio: re-tapping selected chip must not mutate state',
      );
    });
  });

  group('AccountsPage search', () {
    testWidgets('typing in the search box filters the list after debounce', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        accounts: [
          _account(id: 'a', name: 'OpenAI Main', enabled: true),
          _account(id: 'b', name: 'Anthropic Test', enabled: true),
        ],
      );

      await tester.enterText(find.byType(TextField), 'openai');
      // Immediately after typing the debounce timer has not yet fired.
      await tester.pump();
      expect(
        tester.widgetList<AccountCard>(find.byType(AccountCard)).length,
        2,
        reason: 'Before debounce, the list is unchanged',
      );

      // Advance past the 300ms debounce window.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<AccountCard>(find.byType(AccountCard))
          .toList();
      expect(cards.map((c) => c.account.id).toList(), ['a']);
      expect(find.text('全部 (1)'), findsOneWidget);
    });

    testWidgets('clear button appears when input is non-empty and clears it', (
      tester,
    ) async {
      final container = await _pumpPage(
        tester,
        accounts: [
          _account(id: 'a', name: 'alpha', enabled: true),
          _account(id: 'b', name: 'beta', enabled: true),
        ],
      );

      // Initially no clear icon.
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap the clear icon — search query should immediately reset.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(container.read(accountSearchQueryProvider), '');
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('全部 (2)'), findsOneWidget);
    });
  });

  group('AccountsPage empty states', () {
    testWidgets('no accounts at all shows onboarding empty state', (
      tester,
    ) async {
      await _pumpPage(tester, accounts: []);

      expect(find.text('还没有添加任何账号'), findsOneWidget);
      expect(find.text('添加账号'), findsOneWidget);
      expect(find.text('没有匹配的账号'), findsNothing);
    });

    testWidgets(
      'accounts exist but filter excludes all → no-match state with "清除筛选"',
      (tester) async {
        final container = await _pumpPage(
          tester,
          accounts: [
            _account(id: 'a', name: 'A', enabled: true),
            _account(id: 'b', name: 'B', enabled: true),
          ],
        );

        // Switch to disabled tab — no disabled accounts in the fixture.
        container.read(accountListFilterProvider.notifier).state =
            AccountListFilter.disabled;
        await tester.pumpAndSettle();

        expect(find.text('没有匹配的账号'), findsOneWidget);
        expect(find.text('清除筛选'), findsOneWidget);
        expect(find.byType(AccountCard), findsNothing);
      },
    );

    testWidgets('"清除筛选" CTA resets filter to all and clears search text', (
      tester,
    ) async {
      final container = await _pumpPage(
        tester,
        accounts: [_account(id: 'a', name: 'A', enabled: true)],
      );

      // Put the page into a "no match" state: filter=disabled + search=xxx.
      container.read(accountListFilterProvider.notifier).state =
          AccountListFilter.disabled;
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('没有匹配的账号'), findsOneWidget);

      await tester.tap(find.text('清除筛选'));
      await tester.pumpAndSettle();

      expect(container.read(accountListFilterProvider), AccountListFilter.all);
      expect(container.read(accountSearchQueryProvider), '');
      expect(find.byType(AccountCard), findsOneWidget);
    });
  });
}
