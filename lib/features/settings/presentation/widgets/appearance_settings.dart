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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '外观',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        _ThemeModeSelector(
          current: themeMode,
          onSelected: (mode) =>
              ref.read(themeProvider.notifier).setThemeMode(mode),
        ),
        if (dynamicAvailable) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('动态取色'),
            subtitle: const Text('从壁纸或系统主题提取配色'),
            value: dynamicEnabled,
            onChanged: (v) =>
                ref.read(themeProvider.notifier).setDynamicColorEnabled(v),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<AppThemeMode>(
        segments: const [
          ButtonSegment(
            value: AppThemeMode.system,
            label: Text('自动'),
            icon: Icon(Icons.brightness_auto),
          ),
          ButtonSegment(
            value: AppThemeMode.light,
            label: Text('浅色'),
            icon: Icon(Icons.light_mode),
          ),
          ButtonSegment(
            value: AppThemeMode.dark,
            label: Text('深色'),
            icon: Icon(Icons.dark_mode),
          ),
        ],
        selected: {current},
        onSelectionChanged: (s) => onSelected(s.first),
      ),
    );
  }
}
