/// Page that lists ALL persisted request logs across every check-in execution.
///
/// Intended as a debug-only diagnostic tool reachable from Developer Options.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';
import '../../../dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart';
import '../../../dev_tools/request_logger/presentation/widgets/request_log_list_tile.dart';
import '../../data/datasources/check_in_request_log_local_datasource.dart';
import '../providers/check_in_request_log_providers.dart';

/// Displays all persisted request logs with a clear-all action.
class PersistedRequestLogsPage extends ConsumerWidget {
  const PersistedRequestLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(allPersistedRequestLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('持久化请求记录')),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: AppEmptyState(
                icon: Icons.storage_outlined,
                message: '暂无持久化的请求记录',
              ),
            );
          }
          return Column(
            children: [
              _SummaryBar(
                count: logs.length,
                onClear: () => _confirmClear(context, ref),
              ),
              Expanded(child: _LogList(logs: logs)),
            ],
          );
        },
        loading: () => const AppLoadingState(message: '加载中...'),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空持久化记录'),
        content: const Text('确定清空所有持久化的请求记录吗？此操作不可恢复。'),
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
    await ref.read(checkInRequestLogLocalDataSourceProvider).deleteAll();
    if (context.mounted) ref.invalidate(allPersistedRequestLogsProvider);
  }
}

class _SummaryBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;

  const _SummaryBar({required this.count, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Text('共 $count 条', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          IconButton(
            tooltip: '清空所有持久化记录',
            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<RequestLogEntry> logs;
  const _LogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = logs[index];
        return RequestLogListTile(
          entry: entry,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('请求详情')),
                body: RequestLogDetailView(entry: entry),
              ),
            ),
          ),
        );
      },
    );
  }
}
