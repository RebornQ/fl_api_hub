import 'package:flutter/material.dart';

/// Placeholder page for auto check-in feature.
///
/// Will be replaced with task list + config + execution UI in a later batch.
class CheckInPage extends StatelessWidget {
  const CheckInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自动签到')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64),
            SizedBox(height: 16),
            Text('自动签到', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
