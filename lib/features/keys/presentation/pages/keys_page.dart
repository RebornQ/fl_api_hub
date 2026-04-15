import 'package:flutter/material.dart';

/// Placeholder page for API key management feature.
///
/// Will be replaced with a full list + CRUD UI in a later batch.
class KeysPage extends StatelessWidget {
  const KeysPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('密钥管理')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.vpn_key_outlined, size: 64),
            SizedBox(height: 16),
            Text('密钥管理', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
