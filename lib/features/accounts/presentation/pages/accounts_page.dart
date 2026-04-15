import 'package:flutter/material.dart';

/// Placeholder page for account management feature.
///
/// Will be replaced with a full list + CRUD UI in a later batch.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号管理')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_accounts_outlined, size: 64),
            SizedBox(height: 16),
            Text('账号管理', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
