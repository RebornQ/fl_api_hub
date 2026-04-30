/// Settings page shown on the fourth bottom-nav destination.
///
/// Currently serves as a simple launcher for developer options; more
/// groups (theme, backup, scheduler config, …) will be added in later
/// batches.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../backup/presentation/pages/backup_page.dart';
import '../../../dev_tools/request_logger/presentation/pages/developer_options_page.dart';
import '../../domain/entities/global_proxy_setting.dart';
import '../providers/global_proxy_providers.dart';
import '../widgets/appearance_settings.dart';
import '../widgets/browser_settings.dart';
import 'about_page.dart';
import 'network_proxy_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            icon: Icons.travel_explore_outlined,
            title: '网络',
            child: Column(
              children: [const BrowserSettings(), const _NetworkProxyTile()],
            ),
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
            icon: Icons.more_horiz_outlined,
            title: '更多信息',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.developer_mode_outlined),
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
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于 Fl API HUB'),
                  subtitle: const Text('版本信息、开源许可、源码'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Network proxy settings tile that displays the current proxy status.
class _NetworkProxyTile extends ConsumerWidget {
  const _NetworkProxyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSetting = ref.watch(globalProxyProvider);
    final subtitle = _buildSubtitle(asyncSetting);

    return ListTile(
      leading: const Icon(Icons.vpn_key_outlined),
      title: const Text('网络代理'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => NetworkProxySettingsPage.push(context),
    );
  }

  String _buildSubtitle(AsyncValue<GlobalProxySetting> asyncSetting) {
    final setting = asyncSetting.valueOrNull;
    if (setting == null) return '未配置';

    if (!setting.enabled) return '未启用';

    final config = setting.config;
    if (config == null) return '未配置';

    return '已启用 · ${config.scheme.name}://${config.host}:${config.port}';
  }
}
