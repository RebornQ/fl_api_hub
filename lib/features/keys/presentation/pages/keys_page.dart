/// Full keys management page with account selection and CRUD operations.
///
/// Matches the Stitch design: large title, account dropdown, search bar,
/// key cards with masked values, and a stacked FAB group.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/entities/api_key.dart';
import '../providers/keys_providers.dart';
import '../widgets/account_selector.dart';
import '../widgets/key_card.dart';
import '../widgets/key_form_sheet.dart';

/// Keys management page.
class KeysPage extends ConsumerStatefulWidget {
  const KeysPage({super.key});

  @override
  ConsumerState<KeysPage> createState() => _KeysPageState();
}

class _KeysPageState extends ConsumerState<KeysPage> {
  String? _selectedAccountId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);

    // Auto-select the first account when accounts load or when the
    // previously selected account has been deleted.
    accounts.whenData((list) {
      if (_selectedAccountId == null && list.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedAccountId == null) {
            setState(() => _selectedAccountId = list.first.id);
          }
        });
      } else if (_selectedAccountId != null &&
          !list.any((a) => a.id == _selectedAccountId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedAccountId = list.isNotEmpty ? list.first.id : null;
            });
          }
        });
      }
    });

    // Watch keys for the selected account.
    final keys = _selectedAccountId != null
        ? ref.watch(keysProvider(_selectedAccountId!))
        : const AsyncValue<List<ApiKey>>.data([]);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedAccountId != null) {
            ref.invalidate(keysProvider(_selectedAccountId!));
          }
        },
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  _buildAccountSelector(context, accounts),
                  if (_selectedAccountId != null) _buildStatsRow(context, keys),
                  _buildSearchBar(context),
                  Expanded(
                    child: _selectedAccountId == null
                        ? _buildNoAccountsState(context)
                        : keys.when(
                            data: (list) => _buildList(context, ref, list),
                            loading: () =>
                                const AppLoadingState(message: '加载中...'),
                            error: (err, _) => AppErrorState(
                              message: err.toString(),
                              onRetry: () => ref.invalidate(
                                keysProvider(_selectedAccountId!),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            if (keys.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: AppLoadingState(),
                ),
              ),
          ],
        ),
      ),
      // FAB group (stacked, right-aligned to match the extended primary FAB).
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Secondary FAB: refresh channels.
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'refresh',
              onPressed: _selectedAccountId != null
                  ? () => ref.invalidate(keysProvider(_selectedAccountId!))
                  : null,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Main FAB: add key (extended, solid brand color, rounded-2xl).
          _buildAddKeyFab(context),
        ],
      ),
    );
  }

  /// Primary extended FAB with icon + label.
  /// Solid brand color + ink splash, matches Stitch design.
  Widget _buildAddKeyFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = _selectedAccountId != null;
    return Hero(
      tag: 'add',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Material(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
          child: InkWell(
            onTap: enabled
                ? () =>
                      KeyFormSheet.show(context, accountId: _selectedAccountId!)
                : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: colorScheme.onPrimary.withValues(alpha: 0.24),
            highlightColor: colorScheme.onPrimary.withValues(alpha: 0.12),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: colorScheme.onPrimary),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Text(
                    '添加密钥',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Page title section.
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
            '密钥管理',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '管理所有中转站账号的 API 密钥，支持一键配置外部工具。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Account selector dropdown.
  Widget _buildAccountSelector(
    BuildContext context,
    AsyncValue<List<Account>> accounts,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: accounts.when(
        data: (list) => AccountSelector(
          accounts: list,
          selectedId: _selectedAccountId,
          onChanged: (id) => setState(() => _selectedAccountId = id),
        ),
        loading: () => const SizedBox(
          height: 56,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (_, _) => AccountSelector(
          accounts: const [],
          selectedId: null,
          onChanged: (_) {},
        ),
      ),
    );
  }

  /// Stats row showing total / enabled / displayed counts.
  Widget _buildStatsRow(BuildContext context, AsyncValue<List<ApiKey>> keys) {
    final list = keys.valueOrNull ?? [];
    final total = list.length;
    final active = list.where((k) => !k.isExpired).length;
    final displayed = _filterKeys(list).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Text(
            '总计 $total 个密钥',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '启用 $active 个',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '显示 $displayed 个',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Search input field.
  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜索密钥名称...',
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md + AppSpacing.xs,
          ),
        ),
      ),
    );
  }

  /// Empty state when no accounts exist.
  Widget _buildNoAccountsState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.3,
        child: const AppEmptyState(
          icon: Icons.manage_accounts_outlined,
          message: '请先添加账号以管理密钥',
        ),
      ),
    );
  }

  /// Builds the filtered key list or empty state.
  Widget _buildList(BuildContext context, WidgetRef ref, List<ApiKey> list) {
    // Resolve the current account for passing to cards.
    final accounts = ref.read(accountsProvider).valueOrNull ?? [];
    final currentAccount = _selectedAccountId != null
        ? accounts.where((a) => a.id == _selectedAccountId).firstOrNull
        : null;

    if (list.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: AppEmptyState(
            icon: Icons.vpn_key_outlined,
            message: '还没有添加任何密钥',
            actionLabel: '添加密钥',
            onAction: _selectedAccountId != null
                ? () =>
                      KeyFormSheet.show(context, accountId: _selectedAccountId!)
                : null,
          ),
        ),
      );
    }

    final filtered = _filterKeys(list);

    if (filtered.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: const AppEmptyState(
            icon: Icons.search_off,
            message: '没有匹配的密钥',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 160), // Space for FAB + nav bar.
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final key = filtered[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: KeyCard(
            apiKey: key,
            account: currentAccount,
            onEdit: () => KeyFormSheet.show(
              context,
              apiKey: key,
              accountId: key.accountId,
            ),
            onDelete: () => _confirmDelete(context, ref, key),
          ),
        );
      },
    );
  }

  /// Filters keys by search query.
  List<ApiKey> _filterKeys(List<ApiKey> keys) {
    if (_searchQuery.isEmpty) return keys;
    return keys
        .where((k) => k.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  /// Shows a confirmation dialog before deleting a key.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ApiKey apiKey,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除密钥'),
        content: Text('确定要删除「${apiKey.name}」吗？此操作无法撤销。'),
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
    if (confirmed == true && _selectedAccountId != null) {
      ref.read(keysProvider(_selectedAccountId!).notifier).delete(apiKey.id);
    }
  }
}
