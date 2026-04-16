/// Check-in results dashboard page.
///
/// Displays a responsive two-column layout (desktop) or single-column
/// layout (mobile) with:
/// - Summary card showing overall status and run times.
/// - Stats grid with aggregate metrics.
/// - Filter chips and search for result filtering.
/// - Scrollable result list with status badges.
/// - FABs for refreshing and executing all enabled tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../domain/entities/check_in_result.dart';
import '../providers/check_in_providers.dart';
import '../widgets/check_in_filter_bar.dart';
import '../widgets/check_in_result_card.dart';
import '../widgets/check_in_stats_grid.dart';
import '../widgets/check_in_summary_card.dart';

/// Check-in results dashboard with responsive layout.
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
    final dashboardAsync = ref.watch(checkInDashboardProvider);
    final stats = ref.watch(checkInStatsProvider);
    final tasksAsync = ref.watch(checkInProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allCheckInResultsProvider);
          ref.invalidate(checkInProvider);
        },
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header.
                  _buildHeader(context),
                  // Responsive body.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        return isWide
                            ? _buildWideLayout(
                                context,
                                stats,
                                dashboardAsync,
                                tasksAsync,
                              )
                            : _buildNarrowLayout(
                                context,
                                stats,
                                dashboardAsync,
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
      // FAB group.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Secondary FAB: refresh.
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton(
              heroTag: 'refresh',
              onPressed: () {
                ref.invalidate(allCheckInResultsProvider);
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
          // Primary FAB: execute all.
          SizedBox(
            width: 64,
            height: 64,
            child: FloatingActionButton(
              heroTag: 'execute',
              onPressed: _isExecuting ? null : _executeAll,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.play_arrow, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  /// Page header with title and description.
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
        ],
      ),
    );
  }

  /// Desktop layout: sidebar + content side by side.
  Widget _buildWideLayout(
    BuildContext context,
    CheckInDashboardStats stats,
    dynamic dashboardAsync,
    dynamic tasksAsync,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left sidebar panel.
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.30,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              160,
            ),
            child: _buildSidebarContent(context, stats),
          ),
        ),
        // Right content panel.
        Expanded(
          child: _buildContentPanel(context, dashboardAsync, tasksAsync),
        ),
      ],
    );
  }

  /// Mobile layout: everything scrolls together vertically.
  Widget _buildNarrowLayout(
    BuildContext context,
    CheckInDashboardStats stats,
    AsyncValue<List<CheckInResultDisplay>> dashboardAsync,
    AsyncValue<dynamic> tasksAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        160,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar content.
          _buildSidebarContent(context, stats),
          const SizedBox(height: AppSpacing.sm),
          // Filter + search.
          CheckInFilterBar(
            selectedFilter: _selectedFilter,
            searchQuery: _searchQuery,
            totalCount:
                ref.watch(checkInStatsProvider).successCount +
                ref.watch(checkInStatsProvider).failedCount +
                ref.watch(checkInStatsProvider).skippedCount,
            successCount: ref.watch(checkInStatsProvider).successCount,
            failedCount: ref.watch(checkInStatsProvider).failedCount,
            skippedCount: ref.watch(checkInStatsProvider).skippedCount,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
            onSearchChanged: (query) {
              setState(() => _searchQuery = query);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Results (shrink-wrapped so parent scrolls).
          dashboardAsync.when(
            data: (displays) =>
                _buildStaticResultList(context, displays, tasksAsync),
            loading: () => const SizedBox(
              height: 200,
              child: AppLoadingState(message: '加载中...'),
            ),
            error: (err, _) => SizedBox(
              height: 200,
              child: AppErrorState(
                message: err.toString(),
                onRetry: () {
                  ref.invalidate(allCheckInResultsProvider);
                  ref.invalidate(checkInProvider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sidebar: summary card + stats grid.
  Widget _buildSidebarContent(
    BuildContext context,
    CheckInDashboardStats stats,
  ) {
    return Column(
      children: [
        CheckInSummaryCard(stats: stats),
        const SizedBox(height: AppSpacing.sm),
        CheckInStatsGrid(stats: stats),
      ],
    );
  }

  /// Right panel: filter bar + result list.
  Widget _buildContentPanel(
    BuildContext context,
    AsyncValue<List<CheckInResultDisplay>> dashboardAsync,
    AsyncValue<dynamic> tasksAsync,
  ) {
    return Column(
      children: [
        // Filter + search.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: CheckInFilterBar(
            selectedFilter: _selectedFilter,
            searchQuery: _searchQuery,
            totalCount:
                ref.watch(checkInStatsProvider).successCount +
                ref.watch(checkInStatsProvider).failedCount +
                ref.watch(checkInStatsProvider).skippedCount,
            successCount: ref.watch(checkInStatsProvider).successCount,
            failedCount: ref.watch(checkInStatsProvider).failedCount,
            skippedCount: ref.watch(checkInStatsProvider).skippedCount,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
            onSearchChanged: (query) {
              setState(() => _searchQuery = query);
            },
          ),
        ),
        // Result list.
        Expanded(
          child: dashboardAsync.when(
            data: (displays) => _buildResultList(context, displays, tasksAsync),
            loading: () => const AppLoadingState(message: '加载中...'),
            error: (err, _) => AppErrorState(
              message: err.toString(),
              onRetry: () {
                ref.invalidate(allCheckInResultsProvider);
                ref.invalidate(checkInProvider);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the filtered result list or appropriate empty state.
  Widget _buildResultList(
    BuildContext context,
    List<CheckInResultDisplay> displays,
    AsyncValue<dynamic> tasksAsync,
  ) {
    // No tasks at all → show empty state.
    final tasks = tasksAsync.valueOrNull ?? [];
    if (tasks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: const AppEmptyState(
            icon: Icons.check_circle_outline,
            message: '暂无签到任务',
          ),
        ),
      );
    }

    // Apply filters.
    var filtered = _filterResults(displays);

    if (filtered.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: const AppEmptyState(
            icon: Icons.event_available_outlined,
            message: '暂无签到记录',
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.md,
        bottom: 160,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CheckInResultCard(display: filtered[index]),
        );
      },
    );
  }

  /// Shrink-wrapped result list for mobile (no Expanded needed).
  Widget _buildStaticResultList(
    BuildContext context,
    List<CheckInResultDisplay> displays,
    AsyncValue<dynamic> tasksAsync,
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

    var filtered = _filterResults(displays);

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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: CheckInResultCard(display: filtered[index]),
        );
      },
    );
  }

  /// Filters results by selected status and search query.
  List<CheckInResultDisplay> _filterResults(
    List<CheckInResultDisplay> displays,
  ) {
    var filtered = displays;

    // Status filter.
    if (_selectedFilter != null) {
      filtered = filtered
          .where((d) => d.result.status == _selectedFilter)
          .toList();
    }

    // Search filter.
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

      // Compute summary.
      final success = results
          .where((r) => r?.status == CheckInStatus.success)
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
