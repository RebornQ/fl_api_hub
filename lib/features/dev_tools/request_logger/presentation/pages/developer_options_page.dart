/// Developer-options secondary page reached from the Settings tab.
///
/// Hosts debug-only tools that are useful during development and
/// production diagnostics. The first such tool is the request logger;
/// future tools (feature flags, logs viewer, …) can be listed here
/// following the same `ListTile` pattern.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../providers/request_logger_providers.dart';
import 'request_logger_page.dart';

class DeveloperOptionsPage extends ConsumerWidget {
  const DeveloperOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = ref.watch(requestLoggerEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
        ),
        children: [
          SwitchListTile.adaptive(
            value: enabled,
            onChanged: (value) =>
                ref.read(requestLoggerEnabledProvider.notifier).state = value,
            title: const Text('请求记录器'),
            subtitle: Text(
              '打开后记录 App 内每个请求（仅内存，关闭或重启后丢失）',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            secondary: Icon(
              enabled ? Icons.wifi_tethering : Icons.wifi_tethering_off,
              color: enabled ? colorScheme.primary : colorScheme.outline,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.list_alt_outlined),
            title: const Text('查看请求记录'),
            subtitle: const Text('实时查看记录 / 搜索 / 筛选'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RequestLoggerPage(),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              '提示',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Text(
              '• 敏感请求头（Authorization / Cookie / New-API-User）默认脱敏显示。\n'
              '• 内存中最多保留 500 条记录，超出后按 FIFO 淘汰。\n'
              '• 关闭开关不会清空已有记录，需要手动在列表页清空。',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
