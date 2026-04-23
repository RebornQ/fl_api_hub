/// Full accounts list page with CRUD operations.
///
/// Supports a responsive master-detail layout:
/// - **Wide (≥900 px)**: left panel (header, search, filter, cards) at 40%
///   width; right panel shows [AccountEditForm] for the selected account.
/// - **Narrow (<900 px)**: single-column layout with full-screen push
///   navigation to [AccountEditPage].
///
/// Matches the Stitch design: large title section, search bar, filter chips,
/// horizontal account cards with status dots, and a stacked FAB group.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../domain/entities/account.dart';
import '../providers/accounts_filter_providers.dart';
import '../providers/accounts_providers.dart';
import '../widgets/account_card.dart';
import '../widgets/account_edit_form.dart';
import 'account_edit_page.dart';

/// Width threshold for the master-detail split.
const _wideBreakpoint = 900.0;

/// Debounce window for the search field.
const _searchDebounce = Duration(milliseconds: 300);

/// Accounts management page.
class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _searchController;
  Timer? _debounce;
  bool _hasSearchText = false;

  late final AnimationController _refreshController;
  bool _isRefreshing = false;

  /// Tracks whether the wide-screen detail panel has unsaved edits.
  final _detailDirtyNotifier = ValueNotifier<bool>(false);

  /// Focus node for capturing keyboard arrow-key events in wide layout.
  final _wideFocusNode = FocusNode();

  /// Per-account item keys used to scroll the selected card into view.
  final _itemKeys = <String, GlobalKey>{};

  /// Key to access the wide-screen detail panel's save method.
  final _detailPanelKey = GlobalKey<_AccountsDetailPanelState>();

  /// Guard flag for the wide-screen save FAB.
  bool _isWideSaving = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    final initialQuery = ref.read(accountSearchQueryProvider);
    _searchController = TextEditingController(text: initialQuery);
    _hasSearchText = initialQuery.isNotEmpty;
    _searchController.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(accountsProvider.notifier).checkAll();
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _debounce?.cancel();
    _detailDirtyNotifier.dispose();
    _wideFocusNode.dispose();
    _searchController
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _refreshController.repeat();
    await ref.read(accountsProvider.notifier).checkAll(force: true);
    if (mounted) {
      _refreshController.stop();
      setState(() => _isRefreshing = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      ref.read(accountSearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(accountSearchQueryProvider.notifier).state = '';
  }

  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(accountSearchQueryProvider.notifier).state = '';
    ref.read(accountListFilterProvider.notifier).state = AccountListFilter.all;
  }

  /// Handles card tap in wide mode with unsaved-changes guard.
  Future<void> _onWideCardTap(Account account) async {
    final currentId = ref.read(selectedAccountIdProvider);
    if (currentId == account.id) return;

    if (_detailDirtyNotifier.value) {
      final discard = await _confirmDiscardDetailEdits();
      if (!discard) return;
    }

    ref.read(selectedAccountIdProvider.notifier).state = account.id;
  }

  Future<bool> _confirmDiscardDetailEdits() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('你有尚未保存的修改，切换账号将会丢失。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Handles ArrowUp / ArrowDown key events to navigate the account list.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final isUp = event.logicalKey == LogicalKeyboardKey.arrowUp;
    final isDown = event.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!isUp && !isDown) return KeyEventResult.ignored;

    final view = ref.read(filteredAccountsProvider).valueOrNull;
    final list = view?.list;
    if (list == null || list.isEmpty) return KeyEventResult.ignored;

    final currentId = ref.read(selectedAccountIdProvider);
    final currentIndex = list.indexWhere((a) => a.id == currentId);

    int nextIndex;
    if (currentIndex < 0) {
      // Nothing selected — pick first.
      nextIndex = 0;
    } else {
      nextIndex = isUp ? currentIndex - 1 : currentIndex + 1;
    }
    if (nextIndex < 0 || nextIndex >= list.length) {
      return KeyEventResult.handled;
    }

    final targetId = list[nextIndex].id;

    // Guard against unsaved edits.
    if (_detailDirtyNotifier.value) {
      _confirmAndSelect(targetId);
      return KeyEventResult.handled;
    }

    ref.read(selectedAccountIdProvider.notifier).state = targetId;
    _scrollToItem(targetId);
    return KeyEventResult.handled;
  }

  Future<void> _confirmAndSelect(String targetId) async {
    final discard = await _confirmDiscardDetailEdits();
    if (!discard || !mounted) return;
    ref.read(selectedAccountIdProvider.notifier).state = targetId;
    _scrollToItem(targetId);
  }

  /// Scrolls the list so the card identified by [accountId] becomes visible.
  void _scrollToItem(String accountId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[accountId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 150),
        );
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(accountsProvider.notifier).checkAll(force: true),
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideBreakpoint;
                return SafeArea(
                  child: isWide
                      ? _buildWideLayout(context, accounts, constraints)
                      : _buildNarrowLayout(context, accounts),
                );
              },
            ),
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
      floatingActionButton: _buildFabGroup(context),
    );
  }

  // ─── Layout variants ───────────────────────────────────────────────

  /// Mobile layout: single scrolling column.
  Widget _buildNarrowLayout(
    BuildContext context,
    AsyncValue<List<Account>> accounts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildSearchAndFilter(context),
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
    );
  }

  /// Desktop layout: sidebar (40%) + detail pane (60%).
  /// Wrapped in [KeyboardListener] for arrow-key navigation.
  Widget _buildWideLayout(
    BuildContext context,
    AsyncValue<List<Account>> accounts,
    BoxConstraints constraints,
  ) {
    return Focus(
      focusNode: _wideFocusNode,
      onKeyEvent: _onKeyEvent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: constraints.maxWidth * 0.40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                _buildSearchAndFilter(context),
                Expanded(
                  child: accounts.when(
                    data: (list) => _buildBody(context, list, isWide: true),
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
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withAlpha(40),
          ),
          Expanded(
            child: _AccountsDetailPanel(
              key: _detailPanelKey,
              dirtyNotifier: _detailDirtyNotifier,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared section builders ───────────────────────────────────────

  /// FAB group: switches between add and save based on wide-screen dirty state.
  Widget _buildFabGroup(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _detailDirtyNotifier,
      builder: (context, isDirty, _) {
        final showSave = isDirty && !_isWideSaving;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Secondary FAB: refresh reachability (hidden when save is shown).
            if (!showSave)
              SizedBox(
                width: 48,
                height: 48,
                child: FloatingActionButton(
                  heroTag: 'accounts_refresh',
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onSecondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: RotationTransition(
                    turns: _refreshController,
                    child: const Icon(Icons.refresh),
                  ),
                ),
              ),
            if (!showSave) const SizedBox(height: AppSpacing.md),
            showSave ? _buildSaveFab(context) : _buildAddFab(context),
          ],
        );
      },
    );
  }

  Widget _buildSaveFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      heroTag: 'save',
      onPressed: _isWideSaving ? null : _onWideSave,
      backgroundColor: colorScheme.tertiary,
      foregroundColor: colorScheme.onTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: _isWideSaving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check, size: 32),
    );
  }

  Future<void> _onWideSave() async {
    final panel = _detailPanelKey.currentState;
    if (panel == null || _isWideSaving) return;

    setState(() => _isWideSaving = true);
    try {
      await panel.save();
    } finally {
      if (mounted) setState(() => _isWideSaving = false);
    }
  }

  Widget _buildAddFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      heroTag: 'add',
      onPressed: () => AccountEditPage.push(context),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: const Icon(Icons.add, size: 32),
    );
  }

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

  Widget _buildBody(
    BuildContext context,
    List<Account> allAccounts, {
    bool isWide = false,
  }) {
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

    return _buildAccountsList(context, view.list, isWide: isWide);
  }

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

  Widget _buildAccountsList(
    BuildContext context,
    List<Account> accounts, {
    bool isWide = false,
  }) {
    final selectedId = isWide ? ref.watch(selectedAccountIdProvider) : null;

    // Ensure every account has a key for scroll-into-view lookups.
    if (isWide) {
      for (final a in accounts) {
        _itemKeys.putIfAbsent(a.id, () => GlobalKey());
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: isWide ? 24 : 160),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isSelected = isWide && account.id == selectedId;
        final itemKey = isWide ? _itemKeys[account.id] : null;

        return Padding(
          key: itemKey,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: AccountCard(
            account: account,
            isSelected: isSelected,
            onTap: () {
              if (isWide) {
                _onWideCardTap(account);
              } else {
                AccountEditPage.push(context, account: account);
              }
            },
            onLongPress: () => _confirmDelete(context, ref, account),
          ),
        );
      },
    );
  }

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
      final deletedId = account.id;
      ref.read(accountsProvider.notifier).delete(deletedId);
      // Clear wide-screen selection if the deleted account was selected.
      if (ref.read(selectedAccountIdProvider) == deletedId) {
        ref.read(selectedAccountIdProvider.notifier).state = null;
      }
    }
  }
}

// ─── Right-hand detail panel (wide layout only) ──────────────────────

class _AccountsDetailPanel extends ConsumerStatefulWidget {
  final ValueNotifier<bool> dirtyNotifier;

  const _AccountsDetailPanel({super.key, required this.dirtyNotifier});

  @override
  ConsumerState<_AccountsDetailPanel> createState() =>
      _AccountsDetailPanelState();
}

class _AccountsDetailPanelState extends ConsumerState<_AccountsDetailPanel> {
  GlobalKey<AccountEditFormState> _formKey = GlobalKey();
  String? _renderedAccountId;

  /// Triggers form validation and save. Returns the saved account or null.
  Future<Account?> save() async {
    final formState = _formKey.currentState;
    if (formState == null) return null;
    final account = await formState.submit();
    if (account != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('账号 ${account.name} 已更新')));
    }
    return account;
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedAccountIdProvider);

    // Force form rebuild when the selected account changes.
    if (selectedId != _renderedAccountId) {
      _renderedAccountId = selectedId;
      _formKey = GlobalKey<AccountEditFormState>();
    }

    if (selectedId == null) {
      return const AppEmptyState(
        icon: Icons.touch_app_outlined,
        message: '选择一个账号查看详情',
      );
    }

    final accounts = ref.watch(accountsProvider);
    final account = accounts.valueOrNull
        ?.where((a) => a.id == selectedId)
        .firstOrNull;

    if (account == null) {
      // Account was deleted — clear selection on next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedAccountIdProvider.notifier).state = null;
        }
      });
      return const AppEmptyState(
        icon: Icons.touch_app_outlined,
        message: '选择一个账号查看详情',
      );
    }

    return AccountEditForm(
      key: _formKey,
      account: account,
      dirtyNotifier: widget.dirtyNotifier,
    );
  }
}

// ─── Filter chip ─────────────────────────────────────────────────────

/// A single filter chip matching the Stitch pill style.
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
