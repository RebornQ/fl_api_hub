library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/browser_providers.dart';

class BrowserSettings extends ConsumerWidget {
  const BrowserSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useInApp = ref.watch(useInAppBrowserProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.open_in_browser),
      title: const Text('使用内置浏览器打开链接'),
      subtitle: const Text('关闭后将使用系统浏览器打开'),
      value: useInApp,
      onChanged: (v) =>
          ref.read(browserProvider.notifier).setUseInAppBrowser(v),
    );
  }
}
