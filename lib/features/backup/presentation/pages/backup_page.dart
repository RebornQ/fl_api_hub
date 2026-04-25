/// Main data management page with backup/restore actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/datasources/backup_file_datasource.dart';
import '../../domain/entities/backup_progress.dart';
import '../providers/backup_providers.dart';
import '../providers/backup_state.dart';
import 'backup_password_dialog.dart';
import 'restore_mode_dialog.dart';
import 'restore_result_page.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SectionCard(
            icon: Icons.backup_outlined,
            title: '备份与恢复',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('创建备份'),
                  subtitle: const Text('将所有数据导出为文件'),
                  trailing: state is BackupInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: state is! BackupInProgress,
                  onTap: () => _onCreateBackup(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('恢复数据'),
                  subtitle: const Text('从备份文件导入数据'),
                  trailing: state is BackupInProgress
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  enabled: state is! BackupInProgress,
                  onTap: () => _onRestore(context, ref),
                ),
              ],
            ),
          ),
          if (state is BackupInProgress) ...[
            const SizedBox(height: 16),
            _ProgressSection(progress: state.progress),
          ],
          if (state is BackupError) ...[
            const SizedBox(height: 8),
            _ErrorSection(exception: state.exception),
          ],
          const SizedBox(height: 8),
          SectionCard(
            icon: Icons.lock_outline,
            title: '加密设置',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('备份加密'),
                  subtitle: const Text('使用密码加密备份文件'),
                  value: ref.watch(isBackupEncryptedProvider),
                  onChanged: (v) => _toggleEncryption(context, ref, v),
                ),
                if (ref.watch(isBackupEncryptedProvider))
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('修改备份密码'),
                    onTap: () => _onChangePassword(context, ref),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateBackup(BuildContext context, WidgetRef ref) async {
    final passwordStore = ref.read(backupPasswordStoreProvider);
    final fileDataSource = ref.read(backupFileDataSourceProvider);

    // If encryption enabled but no password set, prompt for password.
    String? password;
    if (passwordStore.isEncrypted) {
      password = passwordStore.password;
      if (password == null) {
        password = await showBackupPasswordDialog(
          context,
          isConfirm: true,
          title: '设置备份密码',
        );
        if (password == null || !context.mounted) return;
        await passwordStore.setPassword(password);
      }
    }

    await ref.read(backupProvider.notifier).createBackup();

    if (!context.mounted) return;
    final state = ref.read(backupProvider);
    if (state is BackupCreated) {
      await _showExportOptions(context, state.filePath, fileDataSource);
      // Reset state after export flow completes.
      if (context.mounted) {
        ref.read(backupProvider.notifier).reset();
      }
    }
  }

  Future<void> _onRestore(BuildContext context, WidgetRef ref) async {
    final fileDataSource = ref.read(backupFileDataSourceProvider);

    // Pick file.
    final filePath = await fileDataSource.pickFile();
    if (filePath == null || !context.mounted) return;

    // Read first byte to detect encryption.
    final bytes = await fileDataSource.readFile(filePath);
    final isEncrypted = bytes.isNotEmpty && bytes[0] != 0x7B;

    String? password;
    if (isEncrypted) {
      password = await showBackupPasswordDialog(
        context,
        isConfirm: false,
        title: '输入备份密码',
      );
      if (password == null || !context.mounted) return;
    }

    // Choose restore mode.
    final replace = await showRestoreModeDialog(context);
    if (replace == null || !context.mounted) return;

    await ref
        .read(backupProvider.notifier)
        .restoreBackup(
          filePath: filePath,
          password: password,
          replace: replace,
        );

    if (!context.mounted) return;
    final state = ref.read(backupProvider);
    if (state is RestoreCompleted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RestoreResultPage(summary: state.summary),
        ),
      );
      // Reset state after user returns from result page.
      if (context.mounted) {
        ref.read(backupProvider.notifier).reset();
      }
    }
  }

  Future<void> _toggleEncryption(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final passwordStore = ref.read(backupPasswordStoreProvider);
    if (enabled) {
      final password = await showBackupPasswordDialog(
        context,
        isConfirm: true,
        title: '设置备份密码',
      );
      if (password != null) {
        await passwordStore.setPassword(password);
      }
    } else {
      await passwordStore.clearPassword();
    }
  }

  Future<void> _onChangePassword(BuildContext context, WidgetRef ref) async {
    final password = await showBackupPasswordDialog(
      context,
      isConfirm: true,
      title: '修改备份密码',
    );
    if (password != null) {
      await ref.read(backupPasswordStoreProvider).setPassword(password);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('备份密码已更新')));
      }
    }
  }

  Future<void> _showExportOptions(
    BuildContext context,
    String filePath,
    BackupFileDataSource fileDataSource,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('分享'),
              onTap: () async {
                Navigator.pop(ctx);
                await fileDataSource.shareFile(
                  filePath,
                  subject: 'All API Hub 备份文件',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('保存到文件'),
              onTap: () async {
                Navigator.pop(ctx);
                final bytes = await fileDataSource.readFile(filePath);
                await fileDataSource.saveToFile(
                  bytes,
                  filePath.split('/').last,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final BackupProgress progress;
  const _ProgressSection({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress.progress),
          const SizedBox(height: 8),
          Text(progress.phase.label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final AppException exception;
  const _ErrorSection({required this.exception});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exception.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
