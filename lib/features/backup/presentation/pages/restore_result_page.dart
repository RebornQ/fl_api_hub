/// Result summary page shown after a restore operation.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../../backup/domain/repositories/backup_repository.dart';

class RestoreResultPage extends StatelessWidget {
  final RestoreSummary summary;

  const RestoreResultPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('恢复结果')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              '恢复完成',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              summary.wasReplace ? '已使用全量替换模式' : '已使用智能合并模式',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultRow(label: '账号', count: summary.accounts),
                    _ResultRow(label: 'API 密钥', count: summary.keys),
                    _ResultRow(label: '标签', count: summary.tags),
                    _ResultRow(label: '签到任务', count: summary.checkInTasks),
                    _ResultRow(label: '签到记录', count: summary.checkInResults),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => exit(0), child: const Text('退出应用')),
            const SizedBox(height: 8),
            Text(
              '请重新打开应用以加载恢复的数据',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final int count;

  const _ResultRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            '$count 条',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
