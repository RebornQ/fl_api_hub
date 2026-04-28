import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_filter_providers.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/features/tags/domain/entities/tag.dart';
import 'package:fl_api_hub/features/tags/presentation/providers/tags_providers.dart';

/// Minimal notifier stand-in that hands the provided list back from
/// [build] without touching repositories. We don't exercise mutation
/// methods in these tests, so we don't override them.
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

/// Minimal tags notifier stand-in that returns a fixed list from [build].
class _FakeTagsNotifier extends TagsNotifier {
  _FakeTagsNotifier(this._initial);

  final List<Tag> _initial;

  @override
  Future<List<Tag>> build() async => _initial;
}

Account _account({
  required String id,
  required String name,
  String? baseUrl,
  String? notes,
  bool enabled = true,
  List<String> tagIds = const [],
}) {
  return Account(
    id: id,
    name: name,
    baseUrl: baseUrl ?? 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: enabled,
    notes: notes,
    tagIds: tagIds,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Tag _tag({required String id, required String name}) {
  return Tag(
    id: id,
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Future<ProviderContainer> _makeContainer(
  List<Account> accounts, {
  List<Tag> tags = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      accountsProvider.overrideWith(() => _FakeAccountsNotifier(accounts)),
      tagsProvider.overrideWith(() => _FakeTagsNotifier(tags)),
    ],
  );
  // Let the fake notifiers' build() resolve so filteredAccountsProvider
  // has data to work with.
  await container.read(accountsProvider.future);
  await container.read(tagsProvider.future);
  return container;
}

void main() {
  group('filteredAccountsProvider', () {
    test('empty account list returns empty view with zero counts', () async {
      final container = await _makeContainer([]);
      addTearDown(container.dispose);

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list, isEmpty);
      expect(view.countAll, 0);
      expect(view.countEnabled, 0);
      expect(view.countDisabled, 0);
    });

    test(
      'default filter=all + no search returns partitioned list (enabled first)',
      () async {
        final a = _account(id: 'a', name: 'A', enabled: true);
        final b = _account(id: 'b', name: 'B', enabled: false);
        final c = _account(id: 'c', name: 'C', enabled: true);
        final container = await _makeContainer([a, b, c]);
        addTearDown(container.dispose);

        final view = container.read(filteredAccountsProvider).value!;
        expect(
          view.list.map((e) => e.id).toList(),
          ['a', 'c', 'b'],
          reason: 'Stable partition: enabled [A, C] before disabled [B]',
        );
        expect(view.countAll, 3);
        expect(view.countEnabled, 2);
        expect(view.countDisabled, 1);
      },
    );

    test('filter=enabled returns only enabled accounts', () async {
      final a = _account(id: 'a', name: 'A', enabled: true);
      final b = _account(id: 'b', name: 'B', enabled: false);
      final c = _account(id: 'c', name: 'C', enabled: true);
      final container = await _makeContainer([a, b, c]);
      addTearDown(container.dispose);

      container.read(accountListFilterProvider.notifier).state =
          AccountListFilter.enabled;

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a', 'c']);
      // Counts are invariant under filter changes — they reflect the
      // search subset, not the filter selection.
      expect(view.countAll, 3);
      expect(view.countEnabled, 2);
      expect(view.countDisabled, 1);
    });

    test('filter=disabled returns only disabled accounts', () async {
      final a = _account(id: 'a', name: 'A', enabled: true);
      final b = _account(id: 'b', name: 'B', enabled: false);
      final c = _account(id: 'c', name: 'C', enabled: false);
      final container = await _makeContainer([a, b, c]);
      addTearDown(container.dispose);

      container.read(accountListFilterProvider.notifier).state =
          AccountListFilter.disabled;

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['b', 'c']);
      expect(view.countDisabled, 2);
    });

    test('search matches name case-insensitively', () async {
      final a = _account(id: 'a', name: 'OpenAI Main');
      final b = _account(id: 'b', name: 'Anthropic Test');
      final container = await _makeContainer([a, b]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = 'OPENAI';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
      expect(view.countAll, 1);
    });

    test('search matches Chinese characters in name', () async {
      final a = _account(id: 'a', name: '主力账号');
      final b = _account(id: 'b', name: '备用账号');
      final container = await _makeContainer([a, b]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = '主力';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
    });

    test('search matches baseUrl', () async {
      final a = _account(id: 'a', name: 'A', baseUrl: 'https://api.one.com');
      final b = _account(id: 'b', name: 'B', baseUrl: 'https://api.two.com');
      final container = await _makeContainer([a, b]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = 'two';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['b']);
    });

    test('search matches notes and tolerates null notes', () async {
      final a = _account(id: 'a', name: 'A', notes: 'primary heavyweight');
      final b = _account(id: 'b', name: 'B', notes: null);
      final container = await _makeContainer([a, b]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = 'heavy';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
    });

    test(
      'search AND filter compose (enabled only AND name contains)',
      () async {
        final a = _account(id: 'a', name: 'Alpha', enabled: true);
        final b = _account(id: 'b', name: 'Alpha-disabled', enabled: false);
        final c = _account(id: 'c', name: 'Beta', enabled: true);
        final container = await _makeContainer([a, b, c]);
        addTearDown(container.dispose);

        container.read(accountSearchQueryProvider.notifier).state = 'alpha';
        container.read(accountListFilterProvider.notifier).state =
            AccountListFilter.enabled;

        final view = container.read(filteredAccountsProvider).value!;
        expect(view.list.map((e) => e.id).toList(), ['a']);
        // Counts are over the search subset (2 matched "alpha"), before filter.
        expect(view.countAll, 2);
        expect(view.countEnabled, 1);
        expect(view.countDisabled, 1);
      },
    );

    test('counts track the search subset dynamically', () async {
      final a = _account(id: 'a', name: 'gpt-main', enabled: true);
      final b = _account(id: 'b', name: 'gpt-backup', enabled: false);
      final c = _account(id: 'c', name: 'claude', enabled: true);
      final container = await _makeContainer([a, b, c]);
      addTearDown(container.dispose);

      // No search — counts over full list.
      var view = container.read(filteredAccountsProvider).value!;
      expect(view.countAll, 3);
      expect(view.countEnabled, 2);
      expect(view.countDisabled, 1);

      // Narrow the search — counts narrow.
      container.read(accountSearchQueryProvider.notifier).state = 'gpt';
      view = container.read(filteredAccountsProvider).value!;
      expect(view.countAll, 2);
      expect(view.countEnabled, 1);
      expect(view.countDisabled, 1);
    });

    test('search is trimmed before matching', () async {
      final a = _account(id: 'a', name: 'alpha');
      final b = _account(id: 'b', name: 'beta');
      final container = await _makeContainer([a, b]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = '  alpha  ';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
    });

    test(
      'partition is stable across filters (enabled tab keeps input order)',
      () async {
        final a = _account(id: 'a', name: 'A', enabled: true);
        final b = _account(id: 'b', name: 'B', enabled: false);
        final c = _account(id: 'c', name: 'C', enabled: true);
        final d = _account(id: 'd', name: 'D', enabled: false);
        final container = await _makeContainer([a, b, c, d]);
        addTearDown(container.dispose);

        // all
        var view = container.read(filteredAccountsProvider).value!;
        expect(view.list.map((e) => e.id).toList(), ['a', 'c', 'b', 'd']);

        // enabled
        container.read(accountListFilterProvider.notifier).state =
            AccountListFilter.enabled;
        view = container.read(filteredAccountsProvider).value!;
        expect(view.list.map((e) => e.id).toList(), ['a', 'c']);

        // disabled
        container.read(accountListFilterProvider.notifier).state =
            AccountListFilter.disabled;
        view = container.read(filteredAccountsProvider).value!;
        expect(view.list.map((e) => e.id).toList(), ['b', 'd']);
      },
    );
  });

  group('tag name search', () {
    test('search matches account by associated tag name', () async {
      final tagProd = _tag(id: 't1', name: '生产');
      final tagTest = _tag(id: 't2', name: '测试');
      final a = _account(id: 'a', name: 'Alpha', tagIds: ['t1']);
      final b = _account(id: 'b', name: 'Beta', tagIds: ['t2']);
      final container = await _makeContainer([a, b], tags: [tagProd, tagTest]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = '生产';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
    });

    test('search matches tag name case-insensitively', () async {
      final tag = _tag(id: 't1', name: 'Production');
      final a = _account(id: 'a', name: 'Alpha', tagIds: ['t1']);
      final b = _account(id: 'b', name: 'Beta', tagIds: []);
      final container = await _makeContainer([a, b], tags: [tag]);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = 'production';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list.map((e) => e.id).toList(), ['a']);
    });

    test(
      'tag search does not affect existing name/baseUrl/notes matching',
      () async {
        final tag = _tag(id: 't1', name: 'Production');
        final a = _account(id: 'a', name: 'Alpha', tagIds: ['t1']);
        final b = _account(id: 'b', name: 'Beta Production', tagIds: []);
        final container = await _makeContainer([a, b], tags: [tag]);
        addTearDown(container.dispose);

        container.read(accountSearchQueryProvider.notifier).state =
            'production';

        final view = container.read(filteredAccountsProvider).value!;
        // Both matched: a via tag name, b via account name.
        expect(view.list.map((e) => e.id).toList(), ['a', 'b']);
      },
    );

    test('account with unknown tagIds is safely skipped', () async {
      // No tags provided, but account references a tagId that doesn't exist.
      final a = _account(id: 'a', name: 'Alpha', tagIds: ['nonexistent']);
      final container = await _makeContainer([a], tags: []);
      addTearDown(container.dispose);

      container.read(accountSearchQueryProvider.notifier).state = '生产';

      final view = container.read(filteredAccountsProvider).value!;
      expect(view.list, isEmpty);
    });
  });

  group('AccountListFilter.matches', () {
    test('all matches every account', () {
      final enabled = _account(id: 'a', name: 'A', enabled: true);
      final disabled = _account(id: 'b', name: 'B', enabled: false);
      expect(AccountListFilter.all.matches(enabled), isTrue);
      expect(AccountListFilter.all.matches(disabled), isTrue);
    });

    test('enabled only matches enabled', () {
      final enabled = _account(id: 'a', name: 'A', enabled: true);
      final disabled = _account(id: 'b', name: 'B', enabled: false);
      expect(AccountListFilter.enabled.matches(enabled), isTrue);
      expect(AccountListFilter.enabled.matches(disabled), isFalse);
    });

    test('disabled only matches disabled', () {
      final enabled = _account(id: 'a', name: 'A', enabled: true);
      final disabled = _account(id: 'b', name: 'B', enabled: false);
      expect(AccountListFilter.disabled.matches(enabled), isFalse);
      expect(AccountListFilter.disabled.matches(disabled), isTrue);
    });
  });
}
