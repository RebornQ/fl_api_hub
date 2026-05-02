/// Per-account check-in configuration section used inside the account
/// edit page.
///
/// Visual structure mirrors the Stitch "签到配置" section: a primary
/// switch that toggles automatic check-in, followed by two URL fields
/// (custom check-in URL and redemption URL). The redemption URL is
/// intentionally independent of the main switch because it conceptually
/// points at the site's top-up / redemption page, which is orthogonal
/// to daily check-ins.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/check_in_config.dart';

/// Renders the check-in configuration block.
class CheckInConfigSection extends StatefulWidget {
  /// Current per-account check-in configuration.
  final CheckInConfig config;

  /// Current redemption URL value (independent of [config]).
  final String? redemptionUrl;

  /// Called whenever any field inside [CheckInConfig] changes.
  final ValueChanged<CheckInConfig> onConfigChanged;

  /// Called whenever the redemption URL changes. `null` is emitted when the
  /// field is cleared.
  final ValueChanged<String?> onRedemptionUrlChanged;

  const CheckInConfigSection({
    super.key,
    required this.config,
    required this.redemptionUrl,
    required this.onConfigChanged,
    required this.onRedemptionUrlChanged,
  });

  @override
  State<CheckInConfigSection> createState() => _CheckInConfigSectionState();
}

class _CheckInConfigSectionState extends State<CheckInConfigSection> {
  late final TextEditingController _checkInUrlController;
  late final TextEditingController _redeemUrlController;

  @override
  void initState() {
    super.initState();
    _checkInUrlController = TextEditingController(
      text: widget.config.customCheckInUrl ?? '',
    );
    _redeemUrlController = TextEditingController(
      text: widget.redemptionUrl ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant CheckInConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(
      _checkInUrlController,
      widget.config.customCheckInUrl ?? '',
    );
    _syncController(_redeemUrlController, widget.redemptionUrl ?? '');
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = controller.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _checkInUrlController.dispose();
    _redeemUrlController.dispose();
    super.dispose();
  }

  /// Validates an optional URL field.
  ///
  /// Returns `null` when empty (optional field). When non-empty, the value
  /// must start with `http://` or `https://`.
  String? _validateOptionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '请输入有效的 URL（以 http:// 或 https:// 开头）';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = widget.config.autoCheckInEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('checkInAutoSwitch'),
          contentPadding: EdgeInsets.zero,
          title: Text('启用每日自动签到', style: theme.textTheme.bodyMedium),
          subtitle: Text(
            '关闭后，本账号将不参与全局自动签到',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          value: enabled,
          onChanged: (value) {
            widget.onConfigChanged(
              widget.config.copyWith(autoCheckInEnabled: value),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          key: const ValueKey('checkInUrlField'),
          controller: _checkInUrlController,
          enabled: enabled,
          keyboardType: TextInputType.url,
          validator: _validateOptionalUrl,
          decoration: const InputDecoration(
            labelText: '签到 URL（可选）',
            hintText: 'https://welfare.example.com/checkin',
          ),
          onChanged: (value) {
            final trimmed = value.trim();
            final next = trimmed.isEmpty
                ? widget.config.withoutCustomCheckInUrl()
                : widget.config.copyWith(customCheckInUrl: value);
            widget.onConfigChanged(next);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey('redemptionUrlField'),
          controller: _redeemUrlController,
          keyboardType: TextInputType.url,
          validator: _validateOptionalUrl,
          decoration: const InputDecoration(
            labelText: '兑换 URL（可选）',
            hintText: 'https://...',
          ),
          onChanged: (value) {
            final normalized = value.trim().isEmpty ? null : value;
            widget.onRedemptionUrlChanged(normalized);
          },
        ),
      ],
    );
  }
}
