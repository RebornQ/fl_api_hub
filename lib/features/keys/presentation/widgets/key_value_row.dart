/// Masked API key value display with show/hide and copy actions.
///
/// The secret key value is only loaded from [SecureStore] when the user
/// explicitly taps the visibility toggle — never during build.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/result/result.dart';
import '../providers/keys_providers.dart';

/// A row displaying a masked (or revealed) API key value.
class KeyValueRow extends ConsumerStatefulWidget {
  /// The API key ID used to fetch the secret value.
  final String keyId;

  const KeyValueRow({super.key, required this.keyId});

  @override
  ConsumerState<KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends ConsumerState<KeyValueRow> {
  String? _keyValue;
  bool _isVisible = false;
  bool _isLoadingValue = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            child: _isLoadingValue
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isVisible && _keyValue != null
                        ? _keyValue!
                        : 'sk-****...****',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          // Visibility toggle.
          GestureDetector(
            onTap: _toggleVisibility,
            child: Icon(
              _isVisible ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  /// Toggles key value visibility, loading from SecureStore if needed.
  Future<void> _toggleVisibility() async {
    if (!_isVisible) {
      // Show: load value if not already loaded.
      if (_keyValue == null) {
        setState(() => _isLoadingValue = true);
        final repo = ref.read(keysRepositoryProvider);
        final result = await repo.getKeyValue(widget.keyId);
        if (mounted) {
          result.when(
            onSuccess: (value) {
              setState(() {
                _keyValue = value;
                _isLoadingValue = false;
                _isVisible = true;
              });
            },
            onFailure: (_) {
              setState(() => _isLoadingValue = false);
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('无法读取密钥值')));
              }
            },
          );
        }
      } else {
        setState(() => _isVisible = true);
      }
    } else {
      // Hide.
      setState(() => _isVisible = false);
    }
  }
}
