/// Single-row tile for the request logger list.
///
/// Layout (left to right):
///   [method badge] [url · status · elapsed (2-line column)] [chevron]
///
/// The tile is colour-aware when [isSelected] — used by the wide-layout
/// master list to highlight the currently-selected entry.
library;

import 'package:flutter/material.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../domain/entities/request_log_entry.dart';
import 'request_log_method_badge.dart';
import 'request_log_status_badge.dart';

class RequestLogListTile extends StatelessWidget {
  final RequestLogEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const RequestLogListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final path = _pathOnly(entry.url);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withAlpha(120)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RequestLogMethodBadge(method: entry.method),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      path,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        RequestLogStatusBadge(statusCode: entry.statusCode),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _formatElapsed(entry.elapsed),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  /// Extracts `/path?query` from a full URL so the list stays readable.
  /// Falls back to the original string when parsing fails.
  String _pathOnly(String url) {
    try {
      final u = Uri.parse(url);
      final qs = u.hasQuery ? '?${u.query}' : '';
      return u.path.isEmpty ? '/$qs' : '${u.path}$qs';
    } catch (_) {
      return url;
    }
  }

  String _formatElapsed(Duration? d) {
    if (d == null) return '--';
    if (d.inMilliseconds < 1) return '<1 ms';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
    final seconds = d.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(2)} s';
  }
}
