import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/core/network/reachability_status.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/repositories/account_reachability_repository.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/pages/accounts_page.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/providers/account_reachability_providers.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/widgets/account_card.dart';

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
  required bool enabled,
}) {
  return Account(
    id: id,
    name: name,
    baseUrl: 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: enabled,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('AccountsPage ordering', () {
    testWidgets(
      'disabled accounts sink to the bottom while preserving input order',
      (tester) async {
        final accountA = _account(id: 'acc-a', name: 'Alpha', enabled: true);
        final accountB = _account(id: 'acc-b', name: 'Bravo', enabled: false);
        final accountC = _account(id: 'acc-c', name: 'Charlie', enabled: true);

        final fakeNotifier = FakeAccountsNotifier([
          accountA,
          accountB,
          accountC,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountsProvider.overrideWith(() => fakeNotifier),
              accountReachabilityRepositoryProvider.overrideWithValue(
                FakeAccountReachabilityRepository(),
              ),
            ],
            child: const MaterialApp(home: AccountsPage()),
          ),
        );

        // Let the async notifier resolve, the first frame post-callback fire,
        // and the ListView build its cards.
        await tester.pumpAndSettle();

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
}
