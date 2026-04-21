/// A labeled section card used by form layouts.
///
/// Mirrors the Stitch design's "bg-surface-container-low" grouping card
/// where each section has an icon + small upper-case caption followed by
/// the section's content. Keeps vertical rhythm aligned with the
/// application's `AppSpacing` tokens.
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// Displays a rounded card with an icon + title header and the provided
/// [child] below it.
class SectionCard extends StatelessWidget {
  /// Leading icon rendered next to the title.
  final IconData icon;

  /// Section title (rendered as an upper-case caption).
  final String title;

  /// Section content.
  final Widget child;

  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.secondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
