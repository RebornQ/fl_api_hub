import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/app/theme/app_theme.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/check_in_config.dart';
import 'package:fl_api_hub/features/accounts/presentation/pages/account_edit_page.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/features/tags/domain/entities/tag.dart';
import 'package:fl_api_hub/features/tags/domain/repositories/tags_repository.dart';
import 'package:fl_api_hub/features/tags/presentation/providers/tags_providers.dart';

class MockTagsRepository extends Mock implements TagsRepository {}

/// Fake that captures mutations without touching Hive or the network.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this._initial);
  final List<Account> _initial;
  final List<Account> created = [];
  final List<Account> saved = [];
  final List<String> checkedOne = [];

  @override
  Future<List<Account>> build() async => _initial;

  @override
  Future<void> create(Account account) async {
    created.add(account);
    state = AsyncData([..._initial, account]);
  }

  @override
  Future<void> saveAccount(Account account) async {
    saved.add(account);
    state = AsyncData([
      for (final a in _initial) a.id == account.id ? account : a,
    ]);
  }

  @override
  Future<void> checkOne(String id) async {
    checkedOne.add(id);
  }
}

Tag _tag(String id, String name) => Tag(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late FakeAccountsNotifier notifier;
  late MockTagsRepository tagsRepo;

  final existing = Account(
    id: 'acc-1',
    name: 'Existing',
    baseUrl: 'https://existing.example.com/v1',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    username: 'admin',
    userId: 42,
    exchangeRate: 7.3,
    notes: 'Some notes',
    tagIds: const ['t-1'],
    checkIn: const CheckInConfig(
      autoCheckInEnabled: true,
      customCheckInUrl: 'https://checkin.example.com',
    ),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );

  setUp(() {
    notifier = FakeAccountsNotifier([existing]);
    tagsRepo = MockTagsRepository();
    when(() => tagsRepo.getAll()).thenAnswer(
      (_) async => Success([_tag('t-1', 'Prod'), _tag('t-2', 'Staging')]),
    );
  });

  Widget buildHost({Account? account}) {
    return ProviderScope(
      overrides: [
        accountsProvider.overrideWith(() => notifier),
        tagsRepositoryProvider.overrideWithValue(tagsRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: AccountEditPage(account: account),
      ),
    );
  }

  group('AccountEditPage', () {
    testWidgets('edit mode prefills fields from the account', (tester) async {
      await tester.pumpWidget(buildHost(account: existing));
      await tester.pumpAndSettle();

      expect(find.text('编辑账号'), findsOneWidget);
      expect(find.text('Existing'), findsOneWidget);
      expect(find.text('https://existing.example.com/v1'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      // Selected tag renders as a chip with Tag.name.
      expect(find.text('Prod'), findsOneWidget);
    });

    testWidgets('add mode uses empty defaults and says 新增账号', (tester) async {
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(find.text('新增账号'), findsOneWidget);
      // Save FAB is hidden until the form becomes dirty.
      expect(find.byKey(const ValueKey('primarySaveButton')), findsNothing);
    });

    testWidgets(
      'rocket_launch button only appears for managed site types',
      (tester) async {
        await tester.pumpWidget(buildHost());
        await tester.pumpAndSettle();

        // Default siteType is unknown which is non-managed, so the
        // auto-config button is hidden until the user picks a managed type.
        expect(find.byKey(const ValueKey('autoConfigButton')), findsNothing);

        // Switch to new-api (managed).
        await tester.tap(find.byKey(const ValueKey('siteTypeField')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New API').last);
        await tester.pumpAndSettle();

        // NOTE: auto-config button is currently hidden (bottomNavigationBar commented out).
        // When re-enabled, this expectation should be findsOneWidget.
        expect(find.byKey(const ValueKey('autoConfigButton')), findsNothing);

        // Switch to one-api (non-managed).
        await tester.tap(find.byKey(const ValueKey('siteTypeField')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('One API').last);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('autoConfigButton')), findsNothing);
      },
      skip: true, // bottomNavigationBar (_buildAuxBar) is currently disabled
    );

    testWidgets(
      're-detect and auto-config buttons show "即将上线" SnackBars',
      (tester) async {
        await tester.pumpWidget(buildHost());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('reDetectButton')));
        await tester.pump();
        expect(find.text('自动识别功能即将上线～'), findsOneWidget);

        // Force-clear the SnackBar queue so the next one renders
        // immediately; `pumpAndSettle` alone does not advance Timers.
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .clearSnackBars();
        await tester.pumpAndSettle();
        expect(find.text('自动识别功能即将上线～'), findsNothing);

        // The auto-config button is only visible for managed site types;
        // default is unknown (non-managed), so switch to new-api first.
        await tester.tap(find.byKey(const ValueKey('siteTypeField')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New API').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('autoConfigButton')));
        await tester.pump();
        expect(find.text('保存并配置功能即将上线～'), findsOneWidget);
      },
      skip: true, // bottomNavigationBar (_buildAuxBar) is currently disabled
    );

    testWidgets('save in add mode creates account and triggers checkOne', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      // Fill every now-required site-info field; exchangeRate already
      // has a default value in the controller, so it doesn't need input.
      await tester.enterText(
        find.byKey(const ValueKey('nameField')),
        'New Site',
      );
      await tester.enterText(
        find.byKey(const ValueKey('urlField')),
        'https://new.example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('usernameField')),
        'admin',
      );
      await tester.enterText(find.byKey(const ValueKey('userIdField')), '42');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('primarySaveButton')));
      await tester.pumpAndSettle();

      expect(notifier.created, hasLength(1));
      final created = notifier.created.single;
      expect(created.name, 'New Site');
      expect(created.baseUrl, 'https://new.example.com');
      expect(created.username, 'admin');
      expect(created.userId, 42);
      expect(created.enabled, isTrue);
      expect(notifier.checkedOne, [created.id]);
    });

    testWidgets('save in edit mode calls saveAccount with the same id', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost(account: existing));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nameField')),
        'Renamed',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('primarySaveButton')));
      await tester.pumpAndSettle();

      expect(notifier.saved, hasLength(1));
      expect(notifier.saved.single.id, existing.id);
      expect(notifier.saved.single.name, 'Renamed');
    });

    testWidgets(
      'pressing close with unsaved changes shows the discard dialog',
      (tester) async {
        await tester.pumpWidget(buildHost(account: existing));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('nameField')),
          'Changed',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();

        expect(find.text('放弃未保存的更改？'), findsOneWidget);

        // Cancel keeps us on the page.
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('编辑账号'), findsOneWidget);
      },
    );

    testWidgets('validation blocks submit when URL is malformed', (
      tester,
    ) async {
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('nameField')),
        'Bad URL',
      );
      await tester.enterText(
        find.byKey(const ValueKey('urlField')),
        'not-a-url',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('primarySaveButton')));
      await tester.pumpAndSettle();

      expect(notifier.created, isEmpty);
      expect(find.textContaining('请输入有效的 URL'), findsOneWidget);
    });
  });
}
