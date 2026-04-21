/// Full accounts list page with CRUD operations.
///
/// Matches the Stitch design: large title section, search bar, filter chips,
/// horizontal account cards with status dots, and a stacked FAB group.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../domain/entities/account.dart';
import '../providers/accounts_filter_providers.dart';
import '../providers/accounts_providers.dart';
import '../widgets/account_card.dart';
import 'account_edit_page.dart';

/// Debounce window for the search field. Keeps the derived provider from
/// rebuilding on every keystroke while still feeling immediate to users.
const _searchDebounce = Duration(milliseconds: 300);

/// Accounts management page.
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    // Seed the controller from the provider so the search text survives
    // BottomNav tab switches (provider outlives the widget).
    final initialQuery = ref.read(accountSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
    _hasSearchText = initialQuery.isNotEmpty;
    _searchController.addListener(_onControllerChanged);

    // Fire a throttled reachability scan after the first frame. The
    // AccountsNotifier awaits its own load, so this works even when the
    // accounts future has not yet resolved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(accountsProvider.notifier).checkAll();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  /// Drives the suffix-icon visibility without re-running the debounce
  /// write path. Called for both user input and programmatic `clear()`.
  void _onControllerChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
  }

  /// Debounced handler for the search TextField's `onChanged`.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      ref.read(accountSearchQueryProvider.notifier).state = value.trim();
    });
  }

  /// Clears the search box immediately (no debounce) and flushes the
  /// provider so the list reacts on the next frame.
  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(accountSearchQueryProvider.notifier).state = '';
  }

  /// Resets filter to `all` and clears search. Invoked from the "no match"
  /// empty state's CTA button.
  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(accountSearchQueryProvider.notifier).state = '';
    ref.read(accountListFilterProvider.notifier).state = AccountListFilter.all;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(accountsProvider.notifier).checkAll(force: true),
        child: Stack(
          children: [
            // Main content.
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section.
                  _buildHeader(context),
                  // Search & filter section.
                  _buildSearchAndFilter(context),
                  // Account list.
                  Expanded(
                    child: accounts.when(
                      data: (list) => _buildBody(context, list),
                      loading: () => const AppLoadingState(message: '加载中...'),
                      error: (err, _) => AppErrorState(
                        message: err.toString(),
                        onRetry: () => ref.invalidate(accountsProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Loading overlay.
            if (accounts.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: AppLoadingState(),
                ),
              ),
          ],
        ),
      ),
      // FAB group (stacked).
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Secondary FAB: search / scan duplicates.
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'search',
              onPressed: () {
                // TODO: implement scan duplicates
              },
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Main FAB: add account (solid brand color, rounded-2xl).
          _buildAddFab(context),
        ],
      ),
    );
  }

  /// Primary FAB with solid brand color + rounded-2xl + ink splash.
  /// Matches the check-in page execute FAB for visual consistency.
  Widget _buildAddFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Hero(
      tag: 'add',
      child: Material(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        shadowColor: colorScheme.primary.withValues(alpha: 0.4),
        child: InkWell(
          onTap: () => AccountEditPage.push(context),
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.onPrimary.withValues(alpha: 0.24),
          highlightColor: colorScheme.onPrimary.withValues(alpha: 0.12),
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: Icon(Icons.add, size: 32, color: colorScheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }

  /// Large title section matching Stitch design.
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '账号管理',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '一键管理所有AI中转站',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Search input and filter chips.
  Widget _buildSearchAndFilter(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedFilter = ref.watch(accountListFilterProvider);
    final view = ref.watch(filteredAccountsProvider).valueOrNull;

    int countFor(AccountListFilter f) {
      if (view == null) return 0;
      return switch (f) {
        AccountListFilter.all => view.countAll,
        AccountListFilter.enabled => view.countEnabled,
        AccountListFilter.disabled => view.countDisabled,
      };
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          // Search bar.
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _hasSearchText
                  ? IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    )
                  : null,
              hintText: '搜索账号、URL 或标签...',
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm + AppSpacing.xs,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          // Filter chips.
          // TODO 优化：这里的 height 会控制筛选标签列表的高度，可能会导致文字无法居中，建议做成自适应高度
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final filter in AccountListFilter.values) ...[
                  _FilterChip(
                    filter: filter,
                    count: countFor(filter),
                    selected: selectedFilter == filter,
                    onTap: selectedFilter == filter
                        ? null
                        : () =>
                              ref
                                      .read(accountListFilterProvider.notifier)
                                      .state =
                                  filter,
                  ),
                  if (filter != AccountListFilter.values.last)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the body once accounts have loaded.
  ///
  /// Three cases:
  ///   1. No accounts at all — original onboarding empty state.
  ///   2. Accounts exist but filter/search returns none — "no match"
  ///      empty state with a "clear filter" CTA.
  ///   3. Accounts match — list of cards.
  Widget _buildBody(BuildContext context, List<Account> allAccounts) {
    if (allAccounts.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: AppEmptyState(
            icon: Icons.manage_accounts_outlined,
            message: '还没有添加任何账号',
            actionLabel: '添加账号',
            onAction: () => AccountEditPage.push(context),
          ),
        ),
      );
    }

    final view = ref.watch(filteredAccountsProvider).valueOrNull;
    if (view == null || view.list.isEmpty) {
      return _buildNoMatchState(context);
    }

    return _buildAccountsList(context, view.list);
  }

  /// Shown when the accounts list is non-empty but the current filter /
  /// search eliminates every row.
  Widget _buildNoMatchState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.4,
        child: AppEmptyState(
          icon: Icons.search_off,
          message: '没有匹配的账号',
          actionLabel: '清除筛选',
          onAction: _resetFilters,
        ),
      ),
    );
  }

  /// Scrollable list of account cards. Ordering is handled upstream by
  /// [filteredAccountsProvider] (stable partition: enabled → disabled).
  Widget _buildAccountsList(BuildContext context, List<Account> accounts) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 160), // Space for FAB + nav bar.
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: AccountCard(
            account: account,
            onTap: () => AccountEditPage.push(context, account: account),
            onLongPress: () => _confirmDelete(context, ref, account),
          ),
        );
      },
    );
  }

  /// Shows a confirmation dialog before deleting an account.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('确定要删除「${account.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(accountsProvider.notifier).delete(account.id);
    }
  }
}

/// A single filter chip matching the Stitch pill style.
///
/// Renders `"{label} ({count})"`. When [onTap] is `null` the chip acts as
/// a static "currently selected" marker — the Radio semantics forbid
/// de-selecting by tapping the active chip.
class _FilterChip extends StatelessWidget {
  final AccountListFilter filter;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: Text(
              '${filter.label} ($count)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
