/// Narrow-screen page that hosts [CheckInDetailView] for a single account.
///
/// Pushed via `Navigator.push` from the main check-in list when the viewport
/// is below the master-detail breakpoint. On wide screens the same
/// [CheckInDetailView] widget is embedded directly in the right pane.
library;

import 'package:flutter/material.dart';

import '../widgets/check_in_detail_view.dart';

/// Scaffold hosting the per-account check-in history view.
class CheckInAccountDetailPage extends StatelessWidget {
  final String accountId;

  const CheckInAccountDetailPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('签到记录')),
      body: SafeArea(
        child: CheckInDetailView(
          accountId: accountId,
          onCleared: () {
            // After clear-all confirmation, pop back to the master list.
            // The master list refreshes automatically because
            // `clearAll()` invalidates `latestResultPerAccountProvider`.
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}
