import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/app/theme/app_theme.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/check_in_config.dart';
import 'package:fl_api_hub/features/accounts/presentation/widgets/check_in_config_section.dart';

void main() {
  group('CheckInConfigSection', () {
    late CheckInConfig currentConfig;
    late String? currentRedeem;

    Widget harness() {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return CheckInConfigSection(
                config: currentConfig,
                redemptionUrl: currentRedeem,
                onConfigChanged: (c) => setState(() => currentConfig = c),
                onRedemptionUrlChanged: (v) =>
                    setState(() => currentRedeem = v),
              );
            },
          ),
        ),
      );
    }

    setUp(() {
      currentConfig = CheckInConfig.disabled;
      currentRedeem = null;
    });

    testWidgets('toggling switch enables the check-in URL field', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      final urlField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('checkInUrlField')),
      );
      expect(urlField.enabled, isFalse);

      await tester.tap(find.byKey(const ValueKey('checkInAutoSwitch')));
      await tester.pump();

      final urlFieldAfter = tester.widget<TextFormField>(
        find.byKey(const ValueKey('checkInUrlField')),
      );
      expect(urlFieldAfter.enabled, isTrue);
      expect(currentConfig.autoCheckInEnabled, isTrue);
    });

    testWidgets('check-in URL input emits copyWith update', (tester) async {
      currentConfig = const CheckInConfig(autoCheckInEnabled: true);
      await tester.pumpWidget(harness());

      await tester.enterText(
        find.byKey(const ValueKey('checkInUrlField')),
        'https://welfare.example.com',
      );
      await tester.pump();

      expect(currentConfig.customCheckInUrl, 'https://welfare.example.com');
    });

    testWidgets('clearing check-in URL clears customCheckInUrl', (
      tester,
    ) async {
      currentConfig = const CheckInConfig(
        autoCheckInEnabled: true,
        customCheckInUrl: 'https://welfare.example.com',
      );
      await tester.pumpWidget(harness());

      await tester.enterText(find.byKey(const ValueKey('checkInUrlField')), '');
      await tester.pump();

      expect(currentConfig.customCheckInUrl, isNull);
    });

    testWidgets('redemption URL is independent of the main switch', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      // Even when auto-checkin is disabled the redemption field is editable.
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('redemptionUrlField')),
      );
      // `TextField.enabled` is `null` when not explicitly set, which is
      // still effectively enabled by Flutter's conventions.
      expect(field.enabled, isNot(false));

      await tester.enterText(
        find.byKey(const ValueKey('redemptionUrlField')),
        'https://redeem.example.com',
      );
      await tester.pump();
      expect(currentRedeem, 'https://redeem.example.com');
    });
  });
}
