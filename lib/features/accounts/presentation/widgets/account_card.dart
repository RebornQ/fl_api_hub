/// Reusable card displaying a single account's summary.
///
/// Matches the Stitch design: horizontal layout with a status indicator dot
/// on the left, account info in the middle, and balance on the right.
/// Tapping the card opens edit.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/reachability_status.dart';
import '../../../check_in/domain/entities/check_in_result.dart';
import '../../../check_in/presentation/providers/check_in_providers.dart';
import '../../domain/entities/account.dart';
import '../providers/account_reachability_providers.dart';

/// Displays a summary card for a single [Account].
class AccountCard extends ConsumerWidget {
  final Account account;
  final VoidCallback? onTap;

  /// Whether this card is currently selected (wide-screen master-detail).
  final bool isSelected;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDisabled = !account.enabled;

    // Watch the latest check-in result for this account only.
    final latestResult = ref.watch(
      latestResultByAccountProvider.select((map) => map[account.id]),
    );
    final checkInIcon = _resolveCheckInIcon(
      autoCheckInEnabled: account.checkIn.autoCheckInEnabled,
      latestResult: latestResult,
    );

    final Color cardColor;
    final BoxBorder? border;
    if (isSelected) {
      cardColor = colorScheme.primaryContainer;
      border = Border.all(
        color: colorScheme.primary.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      cardColor = isDisabled
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest;
      border = null;
    }

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: border,
        ),
        child: InkWell(
          onTap: onTap,
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
                              // Account name + check-in icon.
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      account.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            height: 1.3,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (checkInIcon != null) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      checkInIcon.icon,
                                      size: 14,
                                      color: checkInIcon.color,
                                    ),
                                  ],
                                ],
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
      ),
    );
  }
}

/// Colored status indicator dot with a glow effect and optional breathing
/// animation while its account is being checked.
///
/// Color priority:
///  1. Disabled → slate gray.
///  2. Reachability failure → red.
///  3. Balance ≤ 1 → orange (low balance warning).
///  4. Otherwise → emerald green (healthy).
///
/// When the account id is in [checkingIdsProvider], the dot continuously
/// scales between 0.85 ↔ 1.15 with opacity pulsing 0.5 ↔ 1.0. Non-checking
/// accounts do not allocate an [AnimationController].
class _StatusDot extends ConsumerStatefulWidget {
  final Account account;

  const _StatusDot({required this.account});

  @override
  ConsumerState<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends ConsumerState<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(
      accountReachabilityMapProvider.select((map) => map[widget.account.id]),
    );
    final isChecking = ref.watch(
      checkingIdsProvider.select((ids) => ids.contains(widget.account.id)),
    );

    if (isChecking) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_controller.value != 0) {
        _controller.value = 0;
      }
    }

    final color = _resolveDotColor(widget.account, record);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0..1
        final scale = 0.85 + 0.30 * t;
        final opacity = 0.5 + 0.5 * (1 - t);
        return Container(
          margin: const EdgeInsets.only(top: 6),
          width: 10,
          height: 10,
          child: Transform.scale(
            scale: isChecking ? scale : 1.0,
            child: Opacity(
              opacity: isChecking ? opacity : 1.0,
              child: DecoratedBox(
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
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Resolves the dot color given the account + current reachability record.
///
/// Pure function (kept at top-level for easy unit testing).
Color _resolveDotColor(Account account, ReachabilityRecord? record) {
  if (!account.enabled) return const Color(0xFF94A3B8); // slate-400, disabled
  if (record != null && record.status == ReachabilityStatus.fail) {
    return const Color(0xFFEF4444); // red-500, site unreachable
  }
  if (account.balance != null && account.balance! <= 1.0) {
    return const Color(0xFFF97316); // orange-500, low balance
  }
  return const Color(0xFF10B981); // emerald-500, healthy
}

/// Resolves the check-in status icon for an account.
///
/// Returns `null` when auto-check-in is disabled (no icon shown).
/// Otherwise returns `(IconData, Color)` based on today's latest result:
/// - success / alreadyChecked → green check_circle
/// - failed                   → orange error
/// - skipped / no result / stale → red cancel
({IconData icon, Color color})? _resolveCheckInIcon({
  required bool autoCheckInEnabled,
  required CheckInResult? latestResult,
}) {
  if (!autoCheckInEnabled) return null;

  if (latestResult == null) {
    return (icon: Icons.cancel, color: const Color(0xFFEF4444));
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final executedAt = latestResult.executedAt;
  final resultDate = DateTime(
    executedAt.year,
    executedAt.month,
    executedAt.day,
  );

  if (resultDate != today) {
    return (icon: Icons.cancel, color: const Color(0xFFEF4444));
  }

  return switch (latestResult.status) {
    CheckInStatus.success || CheckInStatus.alreadyChecked => (
      icon: Icons.check_circle,
      color: const Color(0xFF10B981),
    ),
    CheckInStatus.failed => (icon: Icons.error, color: const Color(0xFFF97316)),
    CheckInStatus.skipped => (
      icon: Icons.cancel,
      color: const Color(0xFFEF4444),
    ),
  };
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
