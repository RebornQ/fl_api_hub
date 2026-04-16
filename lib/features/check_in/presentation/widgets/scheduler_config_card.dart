/// Card widget for auto-check-in scheduler configuration.
///
/// Displays the global enable/disable toggle, time window settings,
/// retry strategy summary, and current scheduler status indicator.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/scheduler_providers.dart';

/// Card showing auto-check-in configuration and controls.
class SchedulerConfigCard extends ConsumerWidget {
  const SchedulerConfigCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(schedulerConfigProvider);
    final isActive = config.enabled;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      color: isActive
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: title + toggle.
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '自动签到',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Status chip.
                _buildStatusChip(context, isActive),
                const SizedBox(width: AppSpacing.sm),
                // Toggle switch.
                Switch(
                  value: config.enabled,
                  onChanged: (value) {
                    ref
                        .read(schedulerConfigProvider.notifier)
                        .setEnabled(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Details (only shown when enabled).
            if (config.enabled) ...[
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              // Time window.
              _buildInfoRow(
                context,
                icon: Icons.access_time_outlined,
                label: '时间窗口',
                value: '${config.timeWindowStart} - ${config.timeWindowEnd}',
                onTap: () => _showTimeWindowDialog(context, ref, config),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Retry strategy.
              _buildInfoRow(
                context,
                icon: Icons.refresh_outlined,
                label: '重试策略',
                value:
                    '间隔 ${config.retryIntervalMinutes} 分钟，最多 ${config.maxRetries} 次',
                onTap: () => _showRetryDialog(context, ref, config),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Status indicator chip.
  Widget _buildStatusChip(BuildContext context, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        isActive ? '活跃' : '未激活',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isActive
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// A single info row with icon, label, value, and optional tap action.
  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to configure the time window.
  Future<void> _showTimeWindowDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic config,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(config.timeWindowStart as String),
      helpText: '选择开始时间',
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(config.timeWindowEnd as String),
      helpText: '选择结束时间',
    );
    if (end == null || !context.mounted) return;

    final startStr =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    ref.read(schedulerConfigProvider.notifier).setTimeWindow(startStr, endStr);
  }

  /// Shows a bottom sheet to configure retry strategy.
  void _showRetryDialog(BuildContext context, WidgetRef ref, dynamic config) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        int interval = config.retryIntervalMinutes as int;
        int maxRetries = config.maxRetries as int;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('重试策略', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  // Retry interval.
                  Text('重试间隔：$interval 分钟'),
                  Slider(
                    value: interval.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$interval 分钟',
                    onChanged: (v) => setSheetState(() => interval = v.round()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Max retries.
                  Text('最大重试次数：$maxRetries 次'),
                  Slider(
                    value: maxRetries.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$maxRetries 次',
                    onChanged: (v) =>
                        setSheetState(() => maxRetries = v.round()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Save button.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(schedulerConfigProvider.notifier)
                            .setRetryStrategy(
                              intervalMinutes: interval,
                              maxRetries: maxRetries,
                            );
                        Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Parses a "HH:mm" string into a [TimeOfDay].
  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
