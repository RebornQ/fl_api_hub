/// Settings page shown on the fourth bottom-nav destination.
///
/// Currently serves as a simple launcher for developer options; more
/// groups (theme, backup, scheduler config, …) will be added in later
/// batches.
library;

import 'package:flutter/material.dart';

import '../../../dev_tools/request_logger/presentation/pages/developer_options_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
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
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}
