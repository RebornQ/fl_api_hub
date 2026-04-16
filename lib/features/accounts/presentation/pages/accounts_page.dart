/// Full accounts list page with CRUD operations.
///
/// Matches the Stitch design: large title section, search bar, filter chips,
/// horizontal account cards with status dots, and a stacked FAB group.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../domain/entities/account.dart';
import '../providers/accounts_providers.dart';
import '../widgets/account_card.dart';
import '../widgets/account_form_sheet.dart';

/// Accounts management page.
class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
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
                      data: (list) => _buildList(context, ref, list),
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
          // Main FAB: add account.
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              heroTag: 'add',
              onPressed: () => AccountFormSheet.show(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.add, size: 32),
            ),
          ),
        ],
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
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜索账号、URL 或标签...',
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
          const SizedBox(height: AppSpacing.sm + 4),
          // Filter chips.
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: '全部', selected: true),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: '已启用'),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: '已禁用'),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: '已同步'),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(label: '警告'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds either the empty state or the list of account cards.
  Widget _buildList(BuildContext context, WidgetRef ref, List<Account> list) {
    if (list.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: AppEmptyState(
            icon: Icons.manage_accounts_outlined,
            message: '还没有添加任何账号',
            actionLabel: '添加账号',
            onAction: () => AccountFormSheet.show(context),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 160), // Space for FAB + nav bar.
      itemCount: list.length,
      itemBuilder: (context, index) {
        final account = list[index];
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: AccountCard(
            account: account,
            onTap: () => AccountFormSheet.show(context, account: account),
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
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _FilterChip({required this.label, this.selected = false});

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
        onTap: () {
          // TODO: implement filter logic
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
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
    );
  }
}
