/// Reusable card displaying a single account's summary.
///
/// Matches the Stitch design: horizontal layout with a status indicator dot
/// on the left, account info in the middle, and balance on the right.
/// Tapping the card opens edit; long-pressing triggers delete confirmation.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/account.dart';

/// Displays a summary card for a single [Account].
class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDisabled = !account.enabled;

    return Card(
      color: isDisabled
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedOpacity(
            opacity: isDisabled ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: info.
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status dot.
                      _StatusDot(account: account),
                      const SizedBox(width: AppSpacing.sm + 4),
                      // Name + type + URL.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Account name.
                            Text(
                              account.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Site type label.
                            Text(
                              account.siteType.displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Base URL (truncated).
                            Text(
                              _stripScheme(account.baseUrl),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: balance + status text.
                _BalanceColumn(
                  account: account,
                  colorScheme: colorScheme,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Colored status indicator dot with a glow effect.
class _StatusDot extends StatelessWidget {
  final Account account;

  const _StatusDot({required this.account});

  @override
  Widget build(BuildContext context) {
    final color = _dotColor;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }

  Color get _dotColor {
    if (!account.enabled) return const Color(0xFF94A3B8); // slate-400
    if (account.balance != null && account.balance! <= 1.0) {
      return const Color(0xFFF97316); // orange-500 — low balance warning
    }
    return const Color(0xFF10B981); // emerald-500 — healthy
  }
}

/// Right-side column showing balance and status text.
class _BalanceColumn extends StatelessWidget {
  final Account account;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _BalanceColumn({
    required this.account,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Balance.
        Text(
          account.balance != null
              ? '\$${_formatBalance(account.balance!)}'
              : '--',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: _balanceColor,
          ),
        ),
        const SizedBox(height: 4),
        // Status text.
        Text(
          _statusText,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: _statusColor,
          ),
        ),
      ],
    );
  }

  Color get _balanceColor {
    if (!account.enabled) return colorScheme.onSurface;
    if (account.balance != null && account.balance! <= 1.0) {
      return colorScheme.error;
    }
    return colorScheme.primary;
  }

  String get _statusText {
    if (!account.enabled) return '已禁用';
    if (account.balance != null && account.balance! <= 1.0) return '余额不足';
    return account.balance != null ? '正常' : '--';
  }

  Color get _statusColor {
    if (!account.enabled) return colorScheme.onSurfaceVariant;
    if (account.balance != null && account.balance! <= 1.0) {
      return colorScheme.error;
    }
    return const Color(0xFF059669); // emerald-600
  }

  String _formatBalance(double value) {
    if (value >= 1000) {
      return value
          .toStringAsFixed(2)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ",");
    }
    return value.toStringAsFixed(2);
  }
}

/// Strips the scheme prefix from a URL for cleaner display.
String _stripScheme(String url) {
  if (url.startsWith('https://')) return url.substring(8);
  if (url.startsWith('http://')) return url.substring(7);
  return url;
}
