/// Export configuration dialog for key export.
///
/// Shows channel type selector (OpenAI/Anthropic/Gemini) and name field,
/// then delegates to the selected [ExportTool].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../data/export/export_tool.dart';

/// Shows the export dialog and returns true if export was triggered.
Future<void> showExportDialog({
  required BuildContext context,
  required ExportTool tool,
  required String defaultName,
  required String apiKey,
  required String baseUrl,
  String homepage = '',
}) {
  return showDialog(
    context: context,
    builder: (context) => _ExportDialog(
      tool: tool,
      defaultName: defaultName,
      apiKey: apiKey,
      baseUrl: baseUrl,
      homepage: homepage,
    ),
  );
}

class _ExportDialog extends StatefulWidget {
  final ExportTool tool;
  final String defaultName;
  final String apiKey;
  final String baseUrl;
  final String homepage;

  const _ExportDialog({
    required this.tool,
    required this.defaultName,
    required this.apiKey,
    required this.baseUrl,
    this.homepage = '',
  });

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final TextEditingController _nameController;
  ChannelType _channelType = ChannelType.openai;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final config = ExportConfig(
      channelType: _channelType,
      name: _nameController.text.trim(),
      apiKey: widget.apiKey,
      baseUrl: widget.baseUrl,
      homepage: widget.homepage,
    );

    try {
      final result = await widget.tool.export(config);

      if (!mounted) return;

      if (widget.tool is CCSwitchExportTool) {
        // Deeplink: handled inside export()
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('正在打开 ${widget.tool.name}...')));
      } else {
        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: result));
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.tool.name} 配置已复制到剪贴板')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('导出到 ${widget.tool.name}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel type selector.
            Text(
              '渠道类型',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            RadioGroup<ChannelType>(
              groupValue: _channelType,
              onChanged: (v) {
                if (v != null) setState(() => _channelType = v);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ChannelType.values
                    .map(
                      (type) => _ChannelRadio(
                        type: type,
                        onTap: () => setState(() => _channelType = type),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Name field.
            Text(
              '供应商名称',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '输入名称',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isExporting ? null : _handleExport,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确定'),
        ),
      ],
    );
  }
}

class _ChannelRadio extends StatelessWidget {
  final ChannelType type;
  final VoidCallback onTap;

  const _ChannelRadio({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<ChannelType>(
              value: type,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(type.label),
          ],
        ),
      ),
    );
  }
}
