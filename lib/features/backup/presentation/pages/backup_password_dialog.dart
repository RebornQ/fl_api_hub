/// Password input dialog for backup encryption.
library;

import 'package:flutter/material.dart';

/// Shows a password dialog and returns the entered password, or `null` if cancelled.
///
/// [isConfirm] = true → shows password + confirm fields (for setting a new password).
/// [isConfirm] = false → shows single password field (for unlocking).
Future<String?> showBackupPasswordDialog(
  BuildContext context, {
  required bool isConfirm,
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _BackupPasswordDialog(isConfirm: isConfirm, title: title),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool isConfirm;
  final String title;

  const _BackupPasswordDialog({required this.isConfirm, required this.title});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) return '密码至少需要 6 个字符';
                return null;
              },
            ),
            if (widget.isConfirm) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: '确认密码',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v != _passwordController.text) return '两次输入的密码不一致';
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _passwordController.text);
    }
  }
}
