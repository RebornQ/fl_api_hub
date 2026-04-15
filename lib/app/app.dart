import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget for the All API Hub application.
///
/// [ProviderScope] wraps the widget tree so that all Riverpod providers are
/// accessible throughout the app.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'All API Hub',
        theme: AppTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
