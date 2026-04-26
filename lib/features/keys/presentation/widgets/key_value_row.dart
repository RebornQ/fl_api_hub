/// Masked API key value display with show/hide toggle and remote resolve.
///
/// Renders [keyValue] in a masked form that uses the real key prefix/suffix
/// by default, and reveals the full value on user tap. When the key appears
/// masked by the server (contains `***`), offers a resolve button that
/// fetches the full key remotely.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../providers/keys_providers.dart';

/// A row displaying a masked (or revealed) API key value.
class KeyValueRow extends ConsumerStatefulWidget {
  /// Secret value to display. May be masked by server (e.g. `sk-***abc`).
  final String? keyValue;

  /// The server-side key ID used for remote resolution.
  final String? keyId;

  /// The account ID this key belongs to (for provider lookup).
  final String accountId;

  const KeyValueRow({
    super.key,
    required this.keyValue,
    this.keyId,
    required this.accountId,
  });

  @override
  ConsumerState<KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends ConsumerState<KeyValueRow> {
  bool _isVisible = false;
  bool _isResolving = false;

  bool get _hasValue => widget.keyValue != null && widget.keyValue!.isNotEmpty;

  /// Whether the server returned a masked key (contains `***` or `…`).
  bool get _isServerMasked =>
      _hasValue &&
      (widget.keyValue!.contains('***') || widget.keyValue!.contains('…'));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = widget.keyValue;

    return Container(
      padding: const EdgeInsets.only(left: 0, right: 12, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '密钥:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              _displayText(value),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Copy button (visible when key is shown and not server-masked).
          if (_isVisible && _hasValue && !_isServerMasked)
            _SmallIconButton(
              icon: Icons.copy,
              tooltip: '复制',
              color: colorScheme.outline,
              onTap: () => _copyToClipboard(value!),
            ),
          // Resolve button (visible when key is server-masked).
          if (_isServerMasked && widget.keyId != null)
            _ResolveButton(
              isResolving: _isResolving,
              onTap: _isResolving ? null : _resolveKey,
            ),
          // Visibility toggle.
          GestureDetector(
            onTap: _hasValue
                ? () => setState(() => _isVisible = !_isVisible)
                : null,
            child: Icon(
              _isVisible ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: _hasValue
                  ? colorScheme.outline
                  : colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the text to display based on visibility and masking state.
  String _displayText(String? value) {
    if (!_hasValue || value == null) return 'sk-****...****';

    // Visible — show the actual value (full key or server-masked string).
    if (_isVisible) return value;

    // Hidden — mask using real prefix and suffix.
    return _maskValue(value);
  }

  /// Masks a key by showing the first 7 and last 4 characters.
  static String _maskValue(String value) {
    if (value.length <= 11) return '${value.substring(0, 3)}...****';
    final prefix = value.substring(0, 7);
    final suffix = value.substring(value.length - 4);
    return '$prefix...$suffix';
  }

  Future<void> _resolveKey() async {
    setState(() => _isResolving = true);
    try {
      await ref
          .read(keysProvider(widget.accountId).notifier)
          .resolveKey(widget.keyId!);
      if (mounted) {
        // Auto-reveal after successful resolve.
        setState(() => _isVisible = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('密钥已解析')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解析失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _copyToClipboard(String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }
}

/// Compact icon button for inline actions.
class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _SmallIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Resolve button with a spinning animation while resolving.
class _ResolveButton extends StatefulWidget {
  final bool isResolving;
  final VoidCallback? onTap;

  const _ResolveButton({required this.isResolving, this.onTap});

  @override
  State<_ResolveButton> createState() => _ResolveButtonState();
}

class _ResolveButtonState extends State<_ResolveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didUpdateWidget(covariant _ResolveButton old) {
    super.didUpdateWidget(old);
    if (widget.isResolving && !old.isResolving) {
      _controller.repeat();
    } else if (!widget.isResolving && old.isResolving) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Tooltip(
        message: '解析完整密钥',
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: RotationTransition(
            turns: _controller,
            child: Icon(Icons.refresh, size: 16, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
