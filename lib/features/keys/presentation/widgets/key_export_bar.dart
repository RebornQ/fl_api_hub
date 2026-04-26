/// Export action bar for key management page.
///
/// Displays export buttons for Claude Code and Cherry Studio at the bottom
/// of the keys page. Each button generates the appropriate config format
/// and copies it to clipboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../data/export/claude_code_exporter.dart';
import '../../data/export/cherry_studio_exporter.dart';
import '../../domain/entities/api_key.dart';

/// A bottom bar with export buttons for external tools.
class KeyExportBar extends StatelessWidget {
  /// Keys to export.
  final List<ApiKey> keys;

  /// Base URL of the selected account.
  final String baseUrl;

  /// Display name for the provider/account.
  final String providerName;

  const KeyExportBar({
    super.key,
    required this.keys,
    required this.baseUrl,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasExportableKeys = keys.any(
      (k) => k.keyValue != null && k.keyValue!.isNotEmpty,
    );

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
        child: Row(
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
                  children: [
                    _ExportChip(
                      label: 'Claude Code',
                      icon: Icons.terminal,
                      enabled: hasExportableKeys,
                      onTap: () => _exportClaudeCode(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _ExportChip(
                      label: 'Cherry Studio',
                      icon: Icons.auto_awesome,
                      enabled: hasExportableKeys,
                      onTap: () => _exportCherryStudio(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportClaudeCode(BuildContext context) {
    final json = keys.length == 1
        ? ClaudeCodeExporter.exportKey(keys.first, baseUrl)
        : ClaudeCodeExporter.exportKeys(keys, baseUrl);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Claude Code 配置已复制到剪贴板（${keys.length} 个密钥）'),
      ),
    );
  }

  void _exportCherryStudio(BuildContext context) {
    final json = keys.length == 1
        ? CherryStudioExporter.exportKey(
            keys.first,
            baseUrl,
            providerName: providerName,
          )
        : CherryStudioExporter.exportKeys(
            keys,
            baseUrl,
            providerName: providerName,
          );
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cherry Studio 配置已复制到剪贴板（${keys.length} 个密钥）'),
      ),
    );
  }
}

/// A compact chip-style button for export actions.
class _ExportChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ExportChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
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
