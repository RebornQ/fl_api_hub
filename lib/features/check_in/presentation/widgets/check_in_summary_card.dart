/// Summary card for the check-in dashboard sidebar.
///
/// Displays the overall execution status badge, next scheduled run time,
/// and last execution time.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/check_in_providers.dart';
import 'check_in_status_badge.dart';

/// Summary information card showing overall status and run times.
class CheckInSummaryCard extends StatelessWidget {
  final CheckInDashboardStats stats;

  const CheckInSummaryCard({super.key, required this.stats});

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
            // Header: label + status badge.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '上次运行',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CheckInOverallStatusBadge(status: stats.overallStatus),
                  ],
                ),
                Icon(Icons.insights, size: 28, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Next run time.
            _InfoRow(
              icon: Icons.schedule,
              label: '下次运行',
              value: _formatDateTime(stats.nextRunAt),
              valueColor: colorScheme.onSurface,
            ),
            const SizedBox(height: 6),
            // Last run time.
            _InfoRow(
              icon: Icons.history,
              label: '上次运行',
              value: _formatDateTime(stats.lastRunAt),
              valueColor: colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Single row with icon, label, and value text.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
