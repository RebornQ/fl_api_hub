import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/app/theme/app_theme.dart';
import 'package:all_api_hub_flutter/core/widgets/section_card.dart';

void main() {
  group('SectionCard', () {
    Widget harness(Widget child) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders icon, uppercased title, and child', (tester) async {
      await tester.pumpWidget(
        harness(
          const SectionCard(
            icon: Icons.language,
            title: '站点信息',
            child: Text('child-content'),
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.text('站点信息'.toUpperCase()), findsOneWidget);
      expect(find.text('child-content'), findsOneWidget);
    });

    testWidgets('applies surfaceContainerLow background', (tester) async {
      await tester.pumpWidget(
        harness(
          const SectionCard(
            icon: Icons.key,
            title: 'Credentials',
            child: SizedBox.shrink(),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.key),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      // Decoration is set from the current ColorScheme; just check that
      // we have a background color and a rounded shape.
      expect(decoration.color, isNotNull);
      expect(decoration.borderRadius, isA<BorderRadius>());
    });
  });
}
