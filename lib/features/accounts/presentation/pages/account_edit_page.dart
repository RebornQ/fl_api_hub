/// Full-screen account edit / add page.
///
/// Uses a FAB for save and a compact bottom bar for auxiliary actions
/// (re-detect, auto-config). The [PopScope] guards against accidental
/// dismissal when the user has unsaved edits.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/site_type.dart';
import '../../domain/entities/account.dart';
import '../widgets/account_edit_form.dart';

/// Full-screen account edit / add page.
class AccountEditPage extends StatefulWidget {
  /// Existing account for edit mode; `null` for add mode.
  final Account? account;

  const AccountEditPage({super.key, this.account});

  /// Convenience push helper used from list entry points.
  static Future<void> push(BuildContext context, {Account? account}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccountEditPage(account: account),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final _formKey = GlobalKey<AccountEditFormState>();
  final _dirtyNotifier = ValueNotifier<bool>(false);
  final _siteTypeNotifier = ValueNotifier<SiteType>(SiteType.unknown);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _dirtyNotifier.dispose();
    _siteTypeNotifier.dispose();
    super.dispose();
  }

  Future<void> _requestClose() async {
    if (!_formKey.currentState!.isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await _confirmDiscardChanges();
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('你有尚未保存的修改，离开将会丢失。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onSave() async {
    final formState = _formKey.currentState;
    if (formState == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final account = await formState.submit();
      if (account == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.account != null
                ? '账号 ${account.name} 已更新'
                : '账号 ${account.name} 已添加',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.account != null;

    return ValueListenableBuilder<bool>(
      valueListenable: _dirtyNotifier,
      builder: (context, isDirty, _) {
        return PopScope(
          canPop: !isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldPop = await _confirmDiscardChanges();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: '关闭',
                icon: const Icon(Icons.close),
                onPressed: _requestClose,
              ),
              title: Text(
                isEditing ? '编辑账号' : '新增账号',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              elevation: 0,
              scrolledUnderElevation: 1,
            ),
            body: AccountEditForm(
              key: _formKey,
              account: widget.account,
              dirtyNotifier: _dirtyNotifier,
              siteTypeNotifier: _siteTypeNotifier,
            ),
            bottomNavigationBar: _buildAuxBar(),
            floatingActionButton: _buildSaveFab(isDirty),
          ),
        );
      },
    );
  }

  /// Save FAB: visible when form is dirty, with loading state.
  Widget _buildSaveFab(bool isDirty) {
    if (!isDirty && !_isSubmitting) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      key: const ValueKey('primarySaveButton'),
      onPressed: _isSubmitting ? null : _onSave,
      backgroundColor: colorScheme.tertiary,
      foregroundColor: colorScheme.onTertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: _isSubmitting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check, size: 32),
    );
  }

  /// Auxiliary action bar: re-detect + auto-config (placeholders).
  Widget _buildAuxBar() {
    return ValueListenableBuilder<SiteType>(
      valueListenable: _siteTypeNotifier,
      builder: (context, siteType, _) {
        return SafeArea(
          top: false,
          child: BottomAppBar(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('reDetectButton'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('自动识别功能即将上线～')),
                      );
                    },
                    child: const Text('重新识别'),
                  ),
                ),
                if (siteType.isManaged) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    key: const ValueKey('autoConfigButton'),
                    tooltip: '保存并配置',
                    icon: const Icon(Icons.rocket_launch),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('保存并配置功能即将上线～')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
