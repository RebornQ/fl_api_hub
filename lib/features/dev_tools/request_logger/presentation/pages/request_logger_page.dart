/// Request logger list page — master-detail entry for inspecting captured
/// requests.
///
/// Responsive layout:
/// - Wide (≥ 900 px): master list on the left (~40 %), vertical divider,
///   detail pane on the right driven by [selectedRequestLogIdProvider].
/// - Narrow (< 900 px): master list only; tapping a tile pushes a
///   [RequestLogDetailPage].
///
/// The AppBar hosts the in-page `Switch` (bound to
/// [requestLoggerEnabledProvider]) and a "清空" icon that empties the
/// buffer after a confirmation dialog. The clear action resets the
/// selected id so the wide-layout detail pane reverts to its empty
/// placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/request_log_entry.dart';
import '../../domain/entities/request_log_filter.dart';
import '../providers/request_logger_providers.dart';
import '../widgets/request_log_detail_placeholder.dart';
import '../widgets/request_log_filter_bar.dart';
import '../widgets/request_log_list_tile.dart';
import 'request_log_detail_page.dart';

class RequestLoggerPage extends ConsumerWidget {
  const RequestLoggerPage({super.key});

  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(requestLoggerEnabledProvider);
    final filtered = ref.watch(filteredRequestLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('请求记录'),
        actions: [
          _AppBarEnabledSwitch(enabled: enabled),
          IconButton(
            tooltip: '清空记录',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: filtered.isEmpty
                ? null
                : () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: const RequestLogFilterBar(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= _wideBreakpoint;
                  return isWide
                      ? _buildWide(context, ref, filtered)
                      : _buildNarrow(context, ref, filtered, enabled);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    WidgetRef ref,
    List<RequestLogEntry> filtered,
  ) {
    final selectedId = ref.watch(selectedRequestLogIdProvider);
    final selectedEntry = selectedId == null
        ? null
        : ref
              .watch(requestLogBufferProvider)
              .where((e) => e.id == selectedId)
              .firstOrNull;

    final enabled = ref.watch(requestLoggerEnabledProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.40,
          child: _buildMasterList(
            context,
            ref,
            filtered,
            enabled: enabled,
            isWide: true,
            selectedId: selectedId,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(40),
        ),
        Expanded(child: RequestLogDetailView(entry: selectedEntry)),
      ],
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    WidgetRef ref,
    List<RequestLogEntry> filtered,
    bool enabled,
  ) {
    return _buildMasterList(
      context,
      ref,
      filtered,
      enabled: enabled,
      isWide: false,
      selectedId: null,
    );
  }

  Widget _buildMasterList(
    BuildContext context,
    WidgetRef ref,
    List<RequestLogEntry> filtered, {
    required bool enabled,
    required bool isWide,
    required int? selectedId,
  }) {
    if (filtered.isEmpty) {
      return _emptyState(context, ref, enabled: enabled);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs + 2),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return RequestLogListTile(
          entry: entry,
          isSelected: isWide && entry.id == selectedId,
          onTap: () {
            if (isWide) {
              ref.read(selectedRequestLogIdProvider.notifier).state = entry.id;
            } else {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RequestLogDetailPage(entryId: entry.id),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _emptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) {
    final buffer = ref.watch(requestLogBufferProvider);
    final filter = ref.watch(requestLogFilterProvider);

    if (!enabled && buffer.isEmpty) {
      return AppEmptyState(
        icon: Icons.toggle_off_outlined,
        message: '请求记录器尚未开启\n打开右上角开关后，新的请求会实时出现在这里',
        actionLabel: '打开开关',
        onAction: () =>
            ref.read(requestLoggerEnabledProvider.notifier).state = true,
      );
    }

    if (buffer.isEmpty) {
      return const AppEmptyState(
        icon: Icons.network_check,
        message: '等待请求中...\n触发任意请求（如签到）即可看到记录',
      );
    }

    // buffer has entries but filter produced nothing.
    return AppEmptyState(
      icon: Icons.filter_alt_off_outlined,
      message: '没有匹配的记录',
      actionLabel: filter.isDefault ? null : '清除筛选',
      onAction: filter.isDefault
          ? null
          : () => ref.read(requestLogFilterProvider.notifier).state =
                const RequestLogFilter(),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空请求记录？'),
        content: const Text('此操作不可撤销。清空后开关保持原状。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(requestLogBufferProvider.notifier).clear();
    ref.read(selectedRequestLogIdProvider.notifier).state = null;
  }
}

class _AppBarEnabledSwitch extends ConsumerWidget {
  final bool enabled;

  const _AppBarEnabledSwitch({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Switch(
        value: enabled,
        onChanged: (value) =>
            ref.read(requestLoggerEnabledProvider.notifier).state = value,
      ),
    );
  }
}
