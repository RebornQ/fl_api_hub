import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/widgets/account_form_sheet.dart';

class MockAccountsRepository extends Mock implements AccountsRepository {}

/// Fake notifier that records mutations without hitting Hive or network.
///
/// Only the methods touched by [AccountFormSheet] are overridden; everything
/// else falls through to [AccountsNotifier] but is never invoked in these
/// tests.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this._initial);

  final List<Account> _initial;

  final List<Account> createdAccounts = [];
  final List<Account> savedAccounts = [];
  final List<String> checkedOneIds = [];

  @override
  Future<List<Account>> build() async => _initial;

  @override
  Future<void> create(Account account) async {
    createdAccounts.add(account);
    state = AsyncData([..._initial, account]);
  }

  @override
  Future<void> saveAccount(Account account) async {
    savedAccounts.add(account);
    state = AsyncData([
      for (final a in _initial) a.id == account.id ? account : a,
    ]);
  }

  @override
  Future<void> checkOne(String id) async {
    checkedOneIds.add(id);
  }
}

void main() {
  late MockAccountsRepository mockRepo;

  final existingEnabled = Account(
    id: 'acc-1',
    name: 'Enabled',
    baseUrl: 'https://enabled.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final existingDisabled = Account(
    id: 'acc-2',
    name: 'Disabled',
    baseUrl: 'https://disabled.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    mockRepo = MockAccountsRepository();
  });

  /// Builds the host MaterialApp that opens the sheet on demand.
  Widget buildHost({
    required FakeAccountsNotifier notifier,
    Account? existing,
  }) {
    return ProviderScope(
      overrides: [
        accountsRepositoryProvider.overrideWithValue(mockRepo),
        accountsProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      AccountFormSheet.show(context, account: existing),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('AccountFormSheet enabled switch', () {
    testWidgets('add mode: switch defaults on; toggling off creates a '
        'disabled account and skips checkOne', (tester) async {
      final fake = FakeAccountsNotifier([existingEnabled]);

      await tester.pumpWidget(buildHost(notifier: fake));
      await openSheet(tester);

      // Switch is visible and on by default.
      final switchFinder = find.byKey(const ValueKey('accountEnabledSwitch'));
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Fill required fields.
      await tester.enterText(find.widgetWithText(TextFormField, '名称'), 'New');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'API 地址'),
        'https://new.example.com',
      );

      // Toggle the switch off.
      await tester.tap(switchFinder);
      await tester.pump();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      // Submit (the form scrolls vertically, so ensure the button is visible).
      final addBtn = find.widgetWithText(FilledButton, '添加');
      await tester.ensureVisible(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(fake.createdAccounts, hasLength(1));
      expect(fake.createdAccounts.single.enabled, isFalse);
      // Submit path skips checkOne when saved as disabled.
      expect(fake.checkedOneIds, isEmpty);
    });

    testWidgets('edit mode on disabled account: other fields are disabled', (
      tester,
    ) async {
      final fake = FakeAccountsNotifier([existingDisabled]);

      await tester.pumpWidget(
        buildHost(notifier: fake, existing: existingDisabled),
      );
      await openSheet(tester);

      // Switch reflects the account state.
      final switchFinder = find.byKey(const ValueKey('accountEnabledSwitch'));
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      // All TextFormFields should be disabled.
      final textFields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textFields, isNotEmpty);
      for (final field in textFields) {
        expect(
          field.enabled,
          isFalse,
          reason:
              'All TextFormField instances should be disabled when the '
              'account is disabled',
        );
      }
    });

    testWidgets('edit mode disabled -> enabled: save triggers checkOne once', (
      tester,
    ) async {
      final fake = FakeAccountsNotifier([existingDisabled]);

      await tester.pumpWidget(
        buildHost(notifier: fake, existing: existingDisabled),
      );
      await openSheet(tester);

      // Flip the switch on.
      final switchFinder = find.byKey(const ValueKey('accountEnabledSwitch'));
      await tester.tap(switchFinder);
      await tester.pump();
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Submit (name/url are already populated from the account).
      final saveBtn = find.widgetWithText(FilledButton, '保存');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(fake.savedAccounts, hasLength(1));
      expect(fake.savedAccounts.single.id, existingDisabled.id);
      expect(fake.savedAccounts.single.enabled, isTrue);
      expect(fake.checkedOneIds, [existingDisabled.id]);
    });
  });
}
