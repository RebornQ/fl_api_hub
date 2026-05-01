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
import '../../domain/entities/account.dart';
import '../providers/account_reachability_providers.dart';

/// Displays a summary card for a single [Account].
class AccountCard extends ConsumerStatefulWidget {
  final Account account;
  final VoidCallback? onTap;

  /// Called when the user long-presses the card in non-edit mode.
  ///
  /// The callback receives the global press [Offset] for positioning
  /// popup menus at the touch point.
  final void Function(Offset)? onLongPress;

  /// Whether this card is currently selected (wide-screen master-detail).
  final bool isSelected;

  /// Whether the list is in edit mode (shows drag handle + wobble animation).
  final bool isEditMode;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isEditMode = false,
  });

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobbleController;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDisabled = !widget.account.enabled;

    // Watch the reachability record for API check-in status.
    final reachabilityRecord = ref.watch(
      accountReachabilityMapProvider.select((map) => map[widget.account.id]),
    );

    final checkInIcon = _resolveCheckInIcon(
      autoCheckInEnabled: widget.account.checkIn.autoCheckInEnabled,
      apiCheckInStatusToday: reachabilityRecord?.checkInStatusToday,
    );

    // Start/stop wobble animation based on edit mode.
    if (widget.isEditMode) {
      if (!_wobbleController.isAnimating) {
        _wobbleController.repeat(reverse: true);
      }
    } else {
      if (_wobbleController.isAnimating) {
        _wobbleController.stop();
      }
      _wobbleController.value = 0;
    }

    final Color cardColor;
    final BoxBorder? border;
    if (widget.isSelected) {
      cardColor = colorScheme.surfaceContainerLow;
      border = Border.all(
        color: colorScheme.primary.withValues(alpha: 0.5),
        width: 1.5,
      );
    } else {
      cardColor = isDisabled
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLow;
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
        child: GestureDetector(
          onLongPressStart: widget.isEditMode || widget.onLongPress == null
              ? null
              : (details) => widget.onLongPress?.call(details.globalPosition),
          onSecondaryTapDown: widget.isEditMode || widget.onLongPress == null
              ? null
              : (details) =>
                    widget.onLongPress?.call(details.globalPosition),
          child: InkWell(
            onTap: widget.onTap,
            // Don't set onLongPress here — it would intercept the GestureDetector's event
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedOpacity(
                opacity: isDisabled ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedBuilder(
                  animation: _wobbleController,
                  builder: (context, child) {
                    // Wobble: ±0.5° rotation (±0.0087 rad)
                    final angle = widget.isEditMode
                        ? 0.0087 * _wobbleController.value * 2 - 0.0087
                        : 0.0;
                    return Transform.rotate(angle: angle, child: child);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: drag handle (edit mode) or status dot.
                      if (widget.isEditMode)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: Icon(
                            Icons.drag_indicator_outlined,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      // Left: info.
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status dot (hidden in edit mode to save space).
                            if (!widget.isEditMode)
                              _StatusDot(account: widget.account),
                            if (!widget.isEditMode)
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
                                          widget.account.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (checkInIcon != null &&
                                          !widget.isEditMode) ...[
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
                                    widget.account.siteType.displayName,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // Base URL (truncated).
                                  Text(
                                    _stripScheme(widget.account.baseUrl),
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
                        account: widget.account,
                        colorScheme: colorScheme,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
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
        final scale = 0.70 + 0.70 * t;
        final opacity = 0.25 + 0.75 * (1 - t);
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
                      color: color.withValues(alpha: isChecking ? 0.6 : 0.4),
                      blurRadius: isChecking ? 12 + 6 * t : 8,
                      spreadRadius: isChecking ? 2 * t : 0,
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
/// Otherwise returns `(IconData, Color)` based solely on API check-in status:
/// - API checkedInToday=true → green check_circle
/// - API checkedInToday=false or unknown → red cancel
///
/// The API status is the single source of truth; local check-in results
/// are not considered for icon display.
({IconData icon, Color color})? _resolveCheckInIcon({
  required bool autoCheckInEnabled,
  required bool? apiCheckInStatusToday,
}) {
  if (!autoCheckInEnabled) return null;

  // API status is the single source of truth.
  if (apiCheckInStatusToday == true) {
    return (icon: Icons.check_circle, color: const Color(0xFF10B981));
  }

  // Not checked in today (or status unknown).
  return (icon: Icons.cancel, color: const Color(0xFFEF4444));
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
