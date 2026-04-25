/// Page showing the network request logs for a single check-in execution.
///
/// Receives the check-in [resultId] (= correlation ID) and loads the
/// associated [RequestLogEntry] list from persistent storage. Tapping a list
/// item navigates to the shared [RequestLogDetailView] detail widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart';
import '../../../dev_tools/request_logger/presentation/widgets/request_log_list_tile.dart';
import '../providers/check_in_request_log_providers.dart';

/// Displays the persisted request logs for a single check-in result.
class CheckInRequestLogsPage extends ConsumerWidget {
  /// The [CheckInResult.id] used as correlation ID to query request logs.
  final String resultId;

  const CheckInRequestLogsPage({super.key, required this.resultId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(checkInRequestLogsProvider(resultId));

    return Scaffold(
      appBar: AppBar(title: const Text('请求记录')),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: AppEmptyState(
                  icon: Icons.http_outlined,
                  message: '该次签到没有请求记录\n被跳过的签到不会产生网络请求',
                ),
              ),
            );
          }
          if (logs.length == 1) {
            return RequestLogDetailView(entry: logs.first);
          }
          return _LogList(logs: logs);
        },
        loading: () => const AppLoadingState(message: '加载中...'),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List logs;
  const _LogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
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
