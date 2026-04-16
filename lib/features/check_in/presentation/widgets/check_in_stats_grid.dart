/// Stats grid for the check-in dashboard sidebar.
///
/// Displays a 2x2 + 1 full-width grid showing:
/// eligible, executed, success (green), failed (red), skipped.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/check_in_providers.dart';

/// Aggregate statistics grid with colored accent borders.
class CheckInStatsGrid extends StatelessWidget {
  final CheckInDashboardStats stats;

  const CheckInStatsGrid({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Row 1: eligible + executed.
        Row(
          children: [
            Expanded(
              child: _StatCell(label: '可参与', value: '${stats.eligible}'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCell(label: '已执行', value: '${stats.executed}'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row 2: success + failed (with colored borders).
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
                borderColor: Theme.of(context).colorScheme.error,
                labelColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row 3: skipped (full width).
        Row(
          children: [
            Expanded(
              child: _StatCell(label: '已跳过', value: '${stats.skippedCount}'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Single stat cell with optional left accent border.
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
