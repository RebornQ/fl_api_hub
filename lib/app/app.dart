import 'package:flutter/material.dart';

import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

/// Root widget for the All API Hub application.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All API Hub',
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
