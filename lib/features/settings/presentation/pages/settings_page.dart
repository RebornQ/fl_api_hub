/// Settings page shown on the fourth bottom-nav destination.
///
/// Currently serves as a simple launcher for developer options; more
/// groups (theme, backup, scheduler config, …) will be added in later
/// batches.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../backup/presentation/pages/backup_page.dart';
import '../../../dev_tools/request_logger/presentation/pages/developer_options_page.dart';
import '../../../../core/widgets/section_card.dart';
import '../widgets/appearance_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        children: [
          SectionCard(
            icon: Icons.palette_outlined,
            title: '外观',
            child: const AppearanceSettings(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            icon: Icons.storage_outlined,
            title: '数据管理',
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('备份与恢复'),
              subtitle: const Text('导出、导入或加密备份数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const BackupPage()),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            icon: Icons.developer_mode_outlined,
            title: '开发者',
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('开发者选项'),
              subtitle: const Text('请求记录器等调试工具'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeveloperOptionsPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
