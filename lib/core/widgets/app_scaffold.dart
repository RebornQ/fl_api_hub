/// Shared scaffold with consistent padding, AppBar, and optional loading overlay.
library;

import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';
import 'app_loading_state.dart';

/// Application-wide [Scaffold] wrapper.
///
/// Provides consistent [AppSpacing.md] body padding, an optional [AppBar]
/// when [title] is supplied, and a loading overlay when [isLoading] is true.
class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool isLoading;

  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(title: Text(title!), actions: actions)
          : null,
      body: Stack(
        children: [
          Padding(padding: const EdgeInsets.all(AppSpacing.md), child: body),
          if (isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: AppLoadingState(),
              ),
            ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
