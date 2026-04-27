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
    final dynamicLight = ref.watch(dynamicLightColorSchemeProvider);
    final dynamicDark = ref.watch(dynamicDarkColorSchemeProvider);

    final lightTheme = dynamicLight != null
        ? AppTheme.buildFromScheme(dynamicLight)
        : AppTheme.light;
    final darkTheme = dynamicDark != null
        ? AppTheme.buildFromScheme(dynamicDark)
        : AppTheme.dark;

    return MaterialApp(
      title: 'Fl API Hub',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const AppShell(),
    );
  }
}
