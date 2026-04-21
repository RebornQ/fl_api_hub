/// Summary card for a single account's check-in history.
///
/// Displayed at the top of [CheckInDetailView]. Shows total count, per-
/// status counters (success / failed / skipped), and the most recent
/// execution time for the selected account.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/account_check_in_history_notifier.dart';

/// Summary card presenting aggregate stats for one account.
class AccountCheckInSummaryCard extends StatelessWidget {
  final String accountName;
  final AccountCheckInStats stats;

  const AccountCheckInSummaryCard({
    super.key,
    required this.accountName,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: account name + icon.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '签到统计',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        accountName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.insights, size: 28, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Total count (large).
            Text(
              '共 ${stats.totalCount} 条记录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Per-status counters.
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: '成功',
                    value: '${stats.successCount}',
                    borderColor: const Color(0xFF059669),
                    labelColor: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCell(
                    label: '失败',
                    value: '${stats.failedCount}',
                    borderColor: colorScheme.error,
                    labelColor: colorScheme.error,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCell(
                    label: '已跳过',
                    value: '${stats.skippedCount}',
                  ),
                ),
              ],
            ),
            if (stats.lastExecutedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '最近签到',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDateTime(stats.lastExecutedAt!),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Single stat cell — mirrors the look of [CheckInStatsGrid]'s cells to keep
/// the detail view visually consistent with the master sidebar.
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? borderColor;
  final Color? labelColor;

  const _StatCell({
    required this.label,
    required this.value,
    this.borderColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: borderColor != null
            ? Border(left: BorderSide(color: borderColor!, width: 3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: labelColor != null
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: labelColor ?? colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
