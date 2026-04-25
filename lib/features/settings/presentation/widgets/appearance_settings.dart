library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/theme_preference.dart';
import '../providers/theme_providers.dart';

/// Appearance settings section with theme mode selector and dynamic color toggle.
class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPref = ref.watch(themeProvider);
    final themeMode = asyncPref.valueOrNull?.themeMode ?? AppThemeMode.system;
    final dynamicEnabled = asyncPref.valueOrNull?.dynamicColorEnabled ?? true;
    final dynamicAvailable = ref.watch(dynamicColorAvailableProvider);

    return Column(
      children: [
        _ThemeModeSelector(
          current: themeMode,
          onSelected: (mode) =>
              ref.read(themeProvider.notifier).setThemeMode(mode),
        ),
        if (dynamicAvailable)
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('动态取色'),
            subtitle: const Text('从壁纸或系统主题提取配色'),
            value: dynamicEnabled,
            onChanged: (v) =>
                ref.read(themeProvider.notifier).setDynamicColorEnabled(v),
          ),
      ],
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final AppThemeMode current;
  final ValueChanged<AppThemeMode> onSelected;

  const _ThemeModeSelector({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    // ListTile layout: leading(56) + content + trailing(~240 for 3 segments)
    // Show title only when enough horizontal space remains.
    const minTitleWidth = 100;
    const estimatedTrailing = 240;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle =
            constraints.maxWidth - estimatedTrailing - 56 > minTitleWidth;
        return ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: showTitle ? const Text('主题模式') : null,
          subtitle: showTitle ? const Text('选择应用的外观主题') : null,
          trailing: SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('自动')),
              ButtonSegment(value: AppThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('深色')),
            ],
            selected: {current},
            onSelectionChanged: (s) => onSelected(s.first),
          ),
        );
      },
    );
  }
}
