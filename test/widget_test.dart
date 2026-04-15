import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/app/app.dart';

void main() {
  testWidgets('App shell renders with bottom navigation', (tester) async {
    await tester.pumpWidget(const App());

    // Default page is Check-in.
    expect(find.text('自动签到'), findsWidgets);

    // Bottom navigation has three destinations.
    expect(find.text('签到'), findsOneWidget);
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('密钥'), findsOneWidget);
  });

  testWidgets('Switching tabs updates the visible page', (tester) async {
    await tester.pumpWidget(const App());

    // Tap the Accounts tab.
    await tester.tap(find.text('账号'));
    await tester.pumpAndSettle();
    expect(find.text('账号管理'), findsWidgets);

    // Tap the Keys tab.
    await tester.tap(find.text('密钥'));
    await tester.pumpAndSettle();
    expect(find.text('密钥管理'), findsWidgets);

    // Tap back to Check-in tab.
    await tester.tap(find.text('签到'));
    await tester.pumpAndSettle();
    expect(find.text('自动签到'), findsWidgets);
  });
}
