/// Export action bar for key management page.
///
/// Displays export tool chips filtered by current platform.
/// Only visible when a key is selected.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../data/export/export_tool.dart';
import '../../domain/entities/api_key.dart';
import 'export_dialog.dart';

/// A bottom bar with platform-filtered export tool chips.
class KeyExportBar extends StatelessWidget {
  /// The selected key to export.
  final ApiKey? apiKey;

  /// Base URL of the selected account.
  final String baseUrl;

  /// Display name for the provider/account.
  final String providerName;

  const KeyExportBar({
    super.key,
    required this.apiKey,
    required this.baseUrl,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tools = platformExportTools;
    final hasApiKey =
        apiKey != null &&
        apiKey!.keyValue != null &&
        apiKey!.keyValue!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: tools.isEmpty
            ? _buildEmptyState(context)
            : Row(
                children: [
                  Text(
                    '导出:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tools
                            .map(
                              (tool) => Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                child: _ExportChip(
                                  label: tool.name,
                                  icon: tool.icon,
                                  enabled: hasApiKey,
                                  onTap: hasApiKey
                                      ? () => showExportDialog(
                                          context: context,
                                          tool: tool,
                                          defaultName: providerName,
                                          apiKey: apiKey!.keyValue!,
                                          baseUrl: baseUrl,
                                          homepage: baseUrl,
                                        )
                                      : null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Text(
          '当前平台暂无支持的导出工具',
          style: TextStyle(fontSize: 12, color: colorScheme.outline),
        ),
      ),
    );
  }
}

/// A compact chip-style button for export actions.
class _ExportChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _ExportChip({
    required this.label,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: enabled
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
