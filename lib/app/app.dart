import 'package:flutter/material.dart';

import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget for the Fl API Hub application.
///
/// The [ProviderScope] is created in [main] via [UncontrolledProviderScope]
/// so the [ProviderContainer] is accessible before [runApp].
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fl API Hub',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
