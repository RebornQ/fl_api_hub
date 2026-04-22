/// Result card for a single check-in execution record.
///
/// Displays account name, colored message, status badge, and timestamp.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/check_in_result.dart';
import '../providers/check_in_providers.dart';
import 'check_in_status_badge.dart';

/// A card displaying a single check-in result with status styling.
class CheckInResultCard extends StatelessWidget {
  final CheckInResultDisplay display;

  const CheckInResultCard({super.key, required this.display});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = display.result;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Account name + status badge.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          display.accountName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                CheckInStatusBadge(status: result.status),
              ],
            ),
            const SizedBox(height: 4),
            // Row 2: Message.
            if (result.message != null)
              Text.rich(
                TextSpan(
                  text: '消息: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: result.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: _messageColor(context, result),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            // Row 3: Timestamp.
            Text(
              _formatDateTime(result.executedAt),
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the message color based on result status.
  Color _messageColor(BuildContext context, CheckInResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (result.status) {
      CheckInStatus.success => const Color(0xFF765B00), // tertiary tone
      CheckInStatus.failed => colorScheme.error,
      CheckInStatus.skipped => colorScheme.onSurfaceVariant,
      CheckInStatus.alreadyChecked => colorScheme.onSurfaceVariant,
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
