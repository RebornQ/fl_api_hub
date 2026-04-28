/// Riverpod providers for filtering and searching the accounts list.
///
/// This layer exposes three concerns:
///  * [accountListFilterProvider] — the current filter chip selection
///    (`all` / `enabled` / `disabled`). Designed as an enum so adding a
///    new chip only requires extending the enum and its helpers.
///  * [accountSearchQueryProvider] — the current debounced search query.
///    The page layer owns the `TextEditingController` and writes the
///    trimmed value here after a 300ms debounce window.
///  * [filteredAccountsProvider] — derives a `FilteredAccountsView` that
///    combines the search-filtered list, the filter selection, and the
///    per-filter counts (computed from the search subset so users can
///    see how the typed query partitions into enabled / disabled).
///
/// Sort: enabled accounts always sink disabled ones to the bottom via a
/// stable O(n) partition, preserving the order within each partition.
/// This mirrors the rule in `accounts_page.dart` so every filter state
/// (and any future chip) keeps the same visual ordering.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/account.dart';
import '../../../tags/presentation/providers/tags_providers.dart';
import 'accounts_providers.dart';

/// Filter chips shown on the accounts management page.
///
/// Add a new value here and extend [matches] + [label] to introduce a
/// new chip. The page re-renders the chip row from the enum order.
enum AccountListFilter {
  all,
  enabled,
  disabled;

  /// Whether [account] should be included under this filter.
  bool matches(Account account) {
    return switch (this) {
      AccountListFilter.all => true,
      AccountListFilter.enabled => account.enabled,
      AccountListFilter.disabled => !account.enabled,
    };
  }

  /// Display label for the filter chip (without the count suffix).
  String get label {
    return switch (this) {
      AccountListFilter.all => '全部',
      AccountListFilter.enabled => '已启用',
      AccountListFilter.disabled => '已禁用',
    };
  }
}

/// Currently selected filter chip. Defaults to [AccountListFilter.all].
///
/// Holds session-scoped state — it survives BottomNav tab switches
/// because Riverpod keeps the provider alive, but resets on app
/// relaunch since no persistence is wired up.
final accountListFilterProvider = StateProvider<AccountListFilter>(
  (ref) => AccountListFilter.all,
);

/// Debounced search query. Empty string means "no search".
///
/// The page debounces `TextField.onChanged` by 300ms before pushing into
/// this provider, so every read here is the stable post-debounce value.
final accountSearchQueryProvider = StateProvider<String>((ref) => '');

/// Materialised view of the accounts list after search + filter are applied.
///
/// Fields:
///  * [list] — accounts matching both the search query and the filter,
///    sorted with disabled accounts sunk to the bottom (stable partition).
///  * [countAll], [countEnabled], [countDisabled] — chip badge counts,
///    computed from the search subset (NOT the filtered list). This lets
///    the badges reflect "within the current search, N are enabled and
///    M are disabled", which is more informative than a static total.
typedef FilteredAccountsView = ({
  List<Account> list,
  int countAll,
  int countEnabled,
  int countDisabled,
});

/// Derives the filtered / searched / counted view from the raw accounts
/// async state plus the two UI state providers.
///
/// Resolution order:
///   1. `accountsProvider` is unwrapped via `whenData` so errors and
///      loading states pass through untouched.
///   2. Search filter — case-insensitive `contains` on `name`, `baseUrl`,
///      `notes`, and associated tag names (via `tagIds` → `tagsProvider`).
///   3. Counts are captured at this stage — they follow the search.
///   4. Chip filter is applied on top.
///   5. Stable partition puts enabled accounts first.
final filteredAccountsProvider = Provider<AsyncValue<FilteredAccountsView>>((
  ref,
) {
  final accounts = ref.watch(accountsProvider);
  final filter = ref.watch(accountListFilterProvider);
  final query = ref.watch(accountSearchQueryProvider).trim().toLowerCase();
  final tagsAsync = ref.watch(tagsProvider);

  // Build a tag ID -> lowercase name lookup for tag-based search matching.
  final tagIdToName = <String, String>{};
  tagsAsync.whenData((tags) {
    for (final tag in tags) {
      tagIdToName[tag.id] = tag.name.toLowerCase();
    }
  });

  return accounts.whenData((list) {
    final searched = query.isEmpty
        ? list
        : list.where((a) {
            if (a.name.toLowerCase().contains(query)) return true;
            if (a.baseUrl.toLowerCase().contains(query)) return true;
            final notes = a.notes;
            if (notes != null && notes.toLowerCase().contains(query)) {
              return true;
            }
            // Tag name matching — case-insensitive contains on tag names
            // referenced by this account.
            for (final tagId in a.tagIds) {
              final tagName = tagIdToName[tagId];
              if (tagName != null && tagName.contains(query)) return true;
            }
            return false;
          }).toList();

    final countAll = searched.length;
    final countEnabled = searched.where((a) => a.enabled).length;
    final countDisabled = countAll - countEnabled;

    final filtered = searched.where(filter.matches).toList();

    // Stable partition — enabled first, disabled sunk to the bottom.
    // Within each partition, respect user-defined sortOrder.
    final enabledAccounts = filtered.where((a) => a.enabled).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final disabledAccounts = filtered.where((a) => !a.enabled).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final sorted = <Account>[...enabledAccounts, ...disabledAccounts];

    return (
      list: sorted,
      countAll: countAll,
      countEnabled: countEnabled,
      countDisabled: countDisabled,
    );
  });
});
