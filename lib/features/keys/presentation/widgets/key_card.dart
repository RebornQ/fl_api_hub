/// A card widget displaying a single API key's details.
///
/// Shows the key name, status badge, masked value, quota stats, and
/// action buttons (copy, edit, delete).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../accounts/domain/entities/account.dart';
import '../../domain/entities/api_key.dart';
import 'key_quota_grid.dart';
import 'key_status_badge.dart';
import 'key_value_row.dart';

/// Displays a single [ApiKey] in a card layout.
class KeyCard extends StatelessWidget {
  final ApiKey apiKey;

  /// The account this key belongs to (may be null during loading).
  final Account? account;

  /// Callback when the user taps edit.
  final VoidCallback? onEdit;

  /// Callback when the user taps delete.
  final VoidCallback? onDelete;

  const KeyCard({
    super.key,
    required this.apiKey,
    this.account,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + badges + action buttons.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + badges.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              apiKey.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          KeyStatusBadge(apiKey: apiKey),
                          if (account != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _AccountBadge(accountName: account!.name),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Admin site info.
                      Text(
                        '管理站点：${account?.baseUrl ?? '未知'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action buttons.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.copy_outlined,
                      tooltip: '复制密钥',
                      onTap: () => _copyKey(context),
                    ),
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: '编辑',
                      onTap: onEdit,
                    ),
                    _ActionButton(
                      icon: Icons.delete_outlined,
                      tooltip: '删除',
                      color: colorScheme.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Key value row (masked/revealed).
            KeyValueRow(keyId: apiKey.id),
            const SizedBox(height: AppSpacing.md),

            // Quota and date grid.
            KeyQuotaGrid(apiKey: apiKey),
          ],
        ),
      ),
    );
  }

  /// Copies the masked representation to clipboard.
  /// Full value copying is handled within [KeyValueRow].
  void _copyKey(BuildContext context) {
    // For now, show a hint that they should use the visibility toggle.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请先显示密钥后再复制')));
  }
}

/// Small account name badge chip.
class _AccountBadge extends StatelessWidget {
  final String accountName;

  const _AccountBadge({required this.accountName});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        accountName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Compact icon button used in the card's action row.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.outline;

    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        color: effectiveColor,
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}
