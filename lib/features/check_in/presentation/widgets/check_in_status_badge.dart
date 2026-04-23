/// Pill-shaped status badge for check-in results.
///
/// Displays "成功" (green), "失败" (red), "已签到" (green), or "已跳过" (yellow)
/// based on [CheckInStatus].
library;

import 'package:flutter/material.dart';

import '../../domain/entities/check_in_result.dart';
import '../providers/check_in_providers.dart';

/// A small pill-shaped badge indicating check-in result status.
class CheckInStatusBadge extends StatelessWidget {
  final CheckInStatus status;

  const CheckInStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor, label) = switch (status) {
      CheckInStatus.success => (
        const Color(0xFFD1FAE5),
        const Color(0xFF047857),
        '成功',
      ),
      CheckInStatus.failed => (
        Theme.of(context).colorScheme.errorContainer,
        Theme.of(context).colorScheme.onErrorContainer,
        '失败',
      ),
      CheckInStatus.skipped => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        '已跳过',
      ),
      CheckInStatus.alreadyChecked => (
        const Color(0xFFD1FAE5),
        const Color(0xFF047857),
        '已签到',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

/// Overall status badge for the summary card.
class CheckInOverallStatusBadge extends StatelessWidget {
  final CheckInOverallStatus status;

  const CheckInOverallStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, textColor, label) = switch (status) {
      CheckInOverallStatus.allSuccess => (
        const Color(0xFFFFDF93),
        const Color(0xFF503D00),
        '全部成功',
      ),
      CheckInOverallStatus.partial => (
        const Color(0xFFFFDF93),
        const Color(0xFF503D00),
        '部分成功',
      ),
      CheckInOverallStatus.allFailed => (
        Theme.of(context).colorScheme.errorContainer,
        Theme.of(context).colorScheme.onErrorContainer,
        '全部失败',
      ),
      CheckInOverallStatus.none => (
        Theme.of(context).colorScheme.surfaceContainerHigh,
        Theme.of(context).colorScheme.onSurfaceVariant,
        '暂无记录',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
