/// Masked API key value display with show/hide toggle.
///
/// Renders [keyValue] (plaintext) in a masked form by default and reveals
/// it on user tap. A `null` or empty [keyValue] is shown as a mask and the
/// visibility toggle is disabled.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';

/// A row displaying a masked (or revealed) API key value.
class KeyValueRow extends StatefulWidget {
  /// Plaintext secret value to display. `null` means not set.
  final String? keyValue;

  const KeyValueRow({super.key, required this.keyValue});

  @override
  State<KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends State<KeyValueRow> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = widget.keyValue;
    final hasValue = value != null && value.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Text(
            '密钥:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.outline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _isVisible && hasValue ? value : 'sk-****...****',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Visibility toggle (disabled when no value).
          GestureDetector(
            onTap: hasValue
                ? () => setState(() => _isVisible = !_isVisible)
                : null,
            child: Icon(
              _isVisible ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: hasValue
                  ? colorScheme.outline
                  : colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}
