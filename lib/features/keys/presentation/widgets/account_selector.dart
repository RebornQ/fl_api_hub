/// Account dropdown selector for the Keys feature.
///
/// Displays a styled dropdown that lets the user pick which account's
/// API keys to view. Shows a disabled state when no accounts exist.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../accounts/domain/entities/account.dart';

/// A dropdown for selecting an account to view its keys.
class AccountSelector extends StatelessWidget {
  /// All available accounts.
  final List<Account> accounts;

  /// Currently selected account ID.
  final String? selectedId;

  /// Callback when the user picks a different account.
  final ValueChanged<String?> onChanged;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = accounts.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择账号',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            suffixIcon: Icon(Icons.unfold_more, color: colorScheme.outline),
          ),
          hint: Text(
            isDisabled ? '请先添加账号' : '选择一个账号',
            style: TextStyle(
              color: isDisabled
                  ? colorScheme.outline
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          items: accounts
              .map(
                (account) => DropdownMenuItem(
                  value: account.id,
                  child: Text(account.name),
                ),
              )
              .toList(),
          onChanged: isDisabled ? null : onChanged,
        ),
      ],
    );
  }
}
