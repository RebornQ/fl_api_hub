import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'shell/app_shell.dart';
import '../features/settings/presentation/providers/theme_providers.dart';

/// Root widget for the Fl API Hub application.
///
/// The [ProviderScope] is created in [main] via [UncontrolledProviderScope]
/// so the [ProviderContainer] is accessible before [runApp].
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final dynamicEnabled = ref.watch(dynamicColorEnabledProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final available = lightDynamic != null;
        // Sync platform support flag once per build.
        if (ref.read(dynamicColorAvailableProvider) != available) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(dynamicColorAvailableProvider.notifier).state = available;
          });
        }
        final lightTheme = dynamicEnabled && lightDynamic != null
            ? AppTheme.buildFromScheme(lightDynamic.harmonized())
            : AppTheme.light;
        final darkTheme = dynamicEnabled && darkDynamic != null
            ? AppTheme.buildFromScheme(darkDynamic.harmonized())
            : AppTheme.dark;

        return MaterialApp(
          title: 'Fl API Hub',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          home: const AppShell(),
        );
      },
    );
  }
}
