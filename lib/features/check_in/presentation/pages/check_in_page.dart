/// Check-in results dashboard page.
///
/// Per-account master-detail layout:
/// - Wide (≥900px): master list on the left; per-account detail pane on
///   the right, initially showing an empty placeholder.
/// - Narrow: single scrolling column; tapping a row pushes
///   [CheckInAccountDetailPage].
///
/// The master list shows one card per account (the account's latest result)
/// and is filtered/searched against that latest-per-account set. Accounts
/// with zero recorded results are hidden.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../providers/check_in_providers.dart';
import '../widgets/check_in_detail_view.dart';
import '../widgets/check_in_filter_bar.dart';
import '../widgets/check_in_result_card.dart';
import '../widgets/check_in_stats_grid.dart';
import '../widgets/check_in_summary_card.dart';
import 'check_in_account_detail_page.dart';

/// Check-in results dashboard with responsive master-detail layout.
class CheckInPage extends ConsumerStatefulWidget {
  const CheckInPage({super.key});

  @override
  ConsumerState<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends ConsumerState<CheckInPage> {
  CheckInStatus? _selectedFilter;
  String _searchQuery = '';
  bool _isExecuting = false;

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(checkInAccountSummariesProvider);
    final stats = ref.watch(checkInStatsProvider);
    final tasksAsync = ref.watch(checkInProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestResultPerAccountProvider);
          ref.invalidate(checkInProvider);
        },
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        return isWide
                            ? _buildWideLayout(
                                context,
                                stats,
                                summariesAsync,
                                tasksAsync,
                              )
                            : _buildNarrowLayout(
                                context,
                                stats,
                                summariesAsync,
                                tasksAsync,
                              );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Loading overlay during execution.
            if (_isExecuting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66FFFFFF),
                  child: AppLoadingState(message: '正在执行签到...'),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'check_in_refresh',
              onPressed: () {
                ref.invalidate(latestResultPerAccountProvider);
                ref.invalidate(checkInProvider);
              },
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
          _buildExecuteFab(context),
        ],
      ),
    );
  }

  /// Primary FAB with solid brand color + rounded-2xl + ink splash.
  Widget _buildExecuteFab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = _isExecuting;
    return Hero(
      tag: 'execute',
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Material(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
          child: InkWell(
            onTap: disabled ? null : _executeAll,
            borderRadius: BorderRadius.circular(16),
            splashColor: colorScheme.onPrimary.withValues(alpha: 0.24),
            highlightColor: colorScheme.onPrimary.withValues(alpha: 0.12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 32,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
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
            '自动签到',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '多账号自动签到任务调度器',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  /// Desktop layout: sidebar (summary + stats + filter + master list) on
  /// the left, detail pane on the right.
  Widget _buildWideLayout(
    BuildContext context,
    CheckInDashboardStats stats,
    AsyncValue<List<CheckInResultDisplay>> summariesAsync,
    AsyncValue<List<CheckInTask>> tasksAsync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.40,
          child: _buildMasterColumn(
            context,
            stats,
            summariesAsync,
            tasksAsync,
            isWide: true,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(40),
        ),
        Expanded(child: _CheckInDetailPanel()),
      ],
    );
  }

  /// Mobile layout: everything scrolls together vertically.
  Widget _buildNarrowLayout(
    BuildContext context,
    CheckInDashboardStats stats,
    AsyncValue<List<CheckInResultDisplay>> summariesAsync,
    AsyncValue<List<CheckInTask>> tasksAsync,
  ) {
    return _buildMasterColumn(
      context,
      stats,
      summariesAsync,
      tasksAsync,
      isWide: false,
    );
  }

  /// Master column: summary/stats/filter + list. Used by both layouts.
  Widget _buildMasterColumn(
    BuildContext context,
    CheckInDashboardStats stats,
    AsyncValue<List<CheckInResultDisplay>> summariesAsync,
    AsyncValue<List<CheckInTask>> tasksAsync, {
    required bool isWide,
  }) {
    final displays = summariesAsync.valueOrNull ?? const [];
    final filtered = _filterResults(displays);
    final successCount = displays
        .where(
          (d) =>
              d.result.status == CheckInStatus.success ||
              d.result.status == CheckInStatus.alreadyChecked,
        )
        .length;
    final failedCount = displays
        .where((d) => d.result.status == CheckInStatus.failed)
        .length;
    final skippedCount = displays
        .where((d) => d.result.status == CheckInStatus.skipped)
        .length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        isWide ? 24 : 160,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckInSummaryCard(stats: stats),
          const SizedBox(height: AppSpacing.sm),
          CheckInStatsGrid(stats: stats),
          const SizedBox(height: AppSpacing.sm),
          CheckInFilterBar(
            selectedFilter: _selectedFilter,
            searchQuery: _searchQuery,
            totalCount: displays.length,
            successCount: successCount,
            failedCount: failedCount,
            skippedCount: skippedCount,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
            onSearchChanged: (query) {
              setState(() => _searchQuery = query);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          summariesAsync.when(
            data: (_) =>
                _buildMasterList(context, filtered, tasksAsync, isWide),
            loading: () => const SizedBox(
              height: 200,
              child: AppLoadingState(message: '加载中...'),
            ),
            error: (err, _) => SizedBox(
              height: 200,
              child: AppErrorState(
                message: err.toString(),
                onRetry: () {
                  ref.invalidate(latestResultPerAccountProvider);
                  ref.invalidate(checkInProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the filtered master list or the appropriate empty state.
  Widget _buildMasterList(
    BuildContext context,
    List<CheckInResultDisplay> filtered,
    AsyncValue<List<CheckInTask>> tasksAsync,
    bool isWide,
  ) {
    final tasks = tasksAsync.valueOrNull ?? [];
    if (tasks.isEmpty) {
      return const SizedBox(
        height: 200,
        child: AppEmptyState(
          icon: Icons.check_circle_outline,
          message: '暂无签到任务',
        ),
      );
    }

    if (filtered.isEmpty) {
      return const SizedBox(
        height: 200,
        child: AppEmptyState(
          icon: Icons.event_available_outlined,
          message: '暂无签到记录',
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final display = filtered[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _TappableResultCard(
            display: display,
            onTap: () => _openDetail(display.result.accountId, isWide),
          ),
        );
      },
    );
  }

  void _openDetail(String accountId, bool isWide) {
    if (isWide) {
      ref.read(selectedAccountIdProvider.notifier).state = accountId;
    } else {
      // Force invalidate cached providers so the pushed detail page always
      // reads fresh data from the database (the wide-screen detail pane is
      // always mounted and stays in sync via ref.listen, but narrow-screen
      // pages are pushed after the data has already settled).
      ref.invalidate(accountCheckInHistoryProvider(accountId));
      ref.invalidate(accountCheckInStatsProvider(accountId));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckInAccountDetailPage(accountId: accountId),
        ),
      );
    }
  }

  /// Filters results by selected status and search query.
  List<CheckInResultDisplay> _filterResults(
    List<CheckInResultDisplay> displays,
  ) {
    var filtered = displays;

    if (_selectedFilter != null) {
      filtered = filtered
          .where((d) => d.result.status == _selectedFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.accountName.toLowerCase().contains(query) ||
            (d.result.message?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// Executes all enabled tasks and shows a result SnackBar.
  Future<void> _executeAll() async {
    setState(() => _isExecuting = true);

    try {
      final results = await ref.read(checkInProvider.notifier).executeAll();

      if (!mounted) return;

      final success = results
          .where(
            (r) =>
                r?.status == CheckInStatus.success ||
                r?.status == CheckInStatus.alreadyChecked,
          )
          .length;
      final failed = results
          .where((r) => r?.status == CheckInStatus.failed)
          .length;
      final skipped = results
          .where((r) => r?.status == CheckInStatus.skipped)
          .length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('执行完成：$success 成功, $failed 失败, $skipped 跳过'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }
}

/// Tappable wrapper around [CheckInResultCard] with ink ripple.
///
/// Kept private to this page so `CheckInResultCard` stays pure/non-tappable
/// when reused in the detail list.
class _TappableResultCard extends StatelessWidget {
  final CheckInResultDisplay display;
  final VoidCallback onTap;

  const _TappableResultCard({required this.display, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: CheckInResultCard(display: display),
      ),
    );
  }
}

/// Right-hand detail pane for the wide-screen master-detail layout.
///
/// Binds to [selectedAccountIdProvider]; shows a placeholder when no account
/// is selected, otherwise hosts [CheckInDetailView] for that account.
class _CheckInDetailPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedAccountIdProvider);
    if (selectedId == null) {
      return const AppEmptyState(
        icon: Icons.touch_app_outlined,
        message: '请在左侧选择一个账号查看签到历史',
      );
    }
    return CheckInDetailView(
      accountId: selectedId,
      onCleared: () {
        // After clear, pop selection back to the placeholder. The master
        // list refreshes automatically via clearAll's invalidation.
        ref.read(selectedAccountIdProvider.notifier).state = null;
      },
    );
  }
}
