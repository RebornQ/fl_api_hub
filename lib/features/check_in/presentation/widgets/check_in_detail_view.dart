/// Shared check-in history detail body used by both the narrow-screen
/// [CheckInAccountDetailPage] and the wide-screen master-detail right pane.
///
/// Layout:
/// - Header row: account name + trailing "clear" icon button.
/// - Summary stats card.
/// - Paginated list of results with infinite scroll.
///
/// The optional [onCleared] callback fires after the user confirms a
/// "clear all" action. Narrow screens hook this up to pop the page; wide
/// screens use it to reset the selected account back to the empty placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/entities/check_in_result.dart';
import '../providers/check_in_providers.dart';
import 'account_check_in_summary_card.dart';
import 'check_in_result_card.dart';

/// Displays one account's paginated check-in history with a top summary
/// card and a clear-all action.
class CheckInDetailView extends ConsumerStatefulWidget {
  final String accountId;

  /// Called after the user confirms "clear all" and the deletion finishes.
  final VoidCallback? onCleared;

  const CheckInDetailView({super.key, required this.accountId, this.onCleared});

  @override
  ConsumerState<CheckInDetailView> createState() => _CheckInDetailViewState();
}

class _CheckInDetailViewState extends ConsumerState<CheckInDetailView> {
  late final ScrollController _scrollController;

  /// Load-more fires once the viewport gets within this many pixels of the
  /// bottom, so the next page is ready before the user reaches it.
  static const double _loadMoreThreshold = 200;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      // Fire-and-forget — the notifier is idempotent while a request is
      // already in flight.
      ref
          .read(accountCheckInHistoryProvider(widget.accountId).notifier)
          .loadMore();
    }
  }

  Future<void> _confirmClear(String accountName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空签到记录'),
        content: Text('确定清空 $accountName 的全部签到记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(accountCheckInHistoryProvider(widget.accountId).notifier)
        .clearAll();

    if (!mounted) return;
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Whenever the master list refreshes (e.g. after execute-all), refetch
    // this account's page too so the open detail pane stays in sync.
    ref.listen<AsyncValue<List<CheckInResult>>>(
      latestResultPerAccountProvider,
      (_, _) {
        ref.invalidate(accountCheckInHistoryProvider(widget.accountId));
        ref.invalidate(accountCheckInStatsProvider(widget.accountId));
      },
    );

    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
    final accountName = account?.name ?? '未知账号';

    final historyAsync = ref.watch(
      accountCheckInHistoryProvider(widget.accountId),
    );
    final statsAsync = ref.watch(accountCheckInStatsProvider(widget.accountId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, accountName),
        Expanded(
          child: historyAsync.when(
            data: (state) =>
                _buildBody(context, state, statsAsync, accountName),
            loading: () => const AppLoadingState(message: '加载中...'),
            error: (err, _) => AppErrorState(
              message: err.toString(),
              onRetry: () => ref.invalidate(
                accountCheckInHistoryProvider(widget.accountId),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String accountName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              accountName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '清空该账号所有记录',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClear(accountName),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AccountCheckInHistoryState state,
    AsyncValue<AccountCheckInStats> statsAsync,
    String accountName,
  ) {
    final stats = statsAsync.valueOrNull ?? AccountCheckInStats.empty;

    if (state.items.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: [
            AccountCheckInSummaryCard(accountName: accountName, stats: stats),
            const SizedBox(height: AppSpacing.md),
            const SizedBox(
              height: 220,
              child: AppEmptyState(
                icon: Icons.event_available_outlined,
                message: '该账号暂无签到记录',
              ),
            ),
          ],
        ),
      );
    }

    // items.length + summary (1) + footer (1).
    final itemCount = state.items.length + 2;
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AccountCheckInSummaryCard(
              accountName: accountName,
              stats: stats,
            ),
          );
        }
        if (index == itemCount - 1) {
          return _buildFooter(context, state);
        }
        final result = state.items[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CheckInResultCard(
            display: CheckInResultDisplay(
              result: result,
              accountName: accountName,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, AccountCheckInHistoryState state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: Text(
            '— 没有更多 —',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
