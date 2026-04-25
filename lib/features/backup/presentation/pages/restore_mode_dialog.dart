/// Restore mode selection dialog (Replace or Merge).
library;

import 'package:flutter/material.dart';

/// Shows a dialog for the user to choose restore mode.
///
/// Returns `true` for replace, `false` for merge, or `null` if cancelled.
Future<bool?> showRestoreModeDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('选择恢复方式'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('备份数据将与当前数据合并或替换。'),
          SizedBox(height: 16),
          _ModeOption(
            icon: Icons.refresh,
            title: '全量替换',
            subtitle: '清除当前所有数据，用备份数据完全替换',
          ),
          SizedBox(height: 12),
          _ModeOption(
            icon: Icons.merge,
            title: '智能合并',
            subtitle: '保留现有数据，合并新增和更新的记录',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('合并'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('替换'),
        ),
      ],
    ),
  );
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
