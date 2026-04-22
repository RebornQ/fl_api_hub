/// Widget tests for [CheckInPage].
///
/// Covers:
/// - Narrow layout: tapping a master-list card pushes
///   [CheckInAccountDetailPage].
/// - Wide layout: tapping a master-list card updates
///   [selectedAccountIdProvider] and surfaces [CheckInDetailView] on the
///   right pane.
/// - Master list filtering: orphan accounts (no matching [accountsProvider]
///   entry) are dropped by [checkInAccountSummariesProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_task.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:all_api_hub_flutter/features/check_in/presentation/pages/check_in_page.dart';
import 'package:all_api_hub_flutter/features/check_in/presentation/providers/check_in_providers.dart';
import 'package:all_api_hub_flutter/features/check_in/presentation/widgets/check_in_result_card.dart';

class _MockCheckInRepository extends Mock implements CheckInRepository {}

/// Fake accounts notifier that short-circuits the reachability scans so the
/// test never needs a Hive-backed reachability repo.
class _FakeAccountsNotifier extends AccountsNotifier {
  _FakeAccountsNotifier(this._initial);

  final List<Account> _initial;

  @override
  Future<List<Account>> build() async => _initial;

  @override
  Future<void> checkAll({bool force = false}) async {}

  @override
  Future<void> checkOne(String id) async {}
}

Account _account({required String id, required String name}) {
  return Account(
    id: id,
    name: name,
    baseUrl: 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: true,
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

CheckInResult _result({required String accountId, String? id}) {
  return CheckInResult(
    id: id ?? 'r-$accountId',
    taskId: 'task-$accountId',
    accountId: accountId,
    status: CheckInStatus.success,
    message: 'ok',
    executedAt: DateTime(2026, 4, 22, 10),
  );
}

CheckInTask _task({required String id, required String accountId}) {
  return CheckInTask(
    id: id,
    accountId: accountId,
    enabled: true,
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

void main() {
  late _MockCheckInRepository repo;

  setUpAll(() {
    registerFallbackValue(
      CheckInResult(
        id: 'fallback',
        taskId: 'fallback',
        accountId: 'fallback',
        status: CheckInStatus.skipped,
        executedAt: DateTime(2026, 4, 22),
      ),
    );
  });

  setUp(() {
    repo = _MockCheckInRepository();
    // Default stubs so every provider read resolves cleanly.
    when(
      () => repo.getAllTasks(),
    ).thenAnswer((_) async => const Success<List<CheckInTask>>([]));
    when(
      () => repo.getLatestResultPerAccount(),
    ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));
    // Detail view + stats provider default fetches (in case the wide-screen
    // detail pane mounts [CheckInDetailView]).
    when(
      () => repo.getResultsByAccountIdPaged(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Success<List<CheckInResult>>([]));
  });

  /// Pumps the page at the given viewport size with the given fake
  /// accounts + task + result fixtures.
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Size size,
    required List<Account> accounts,
    required List<CheckInTask> tasks,
    required List<CheckInResult> latestPerAccount,
  }) async {
    when(() => repo.getAllTasks()).thenAnswer((_) async => Success(tasks));
    when(
      () => repo.getLatestResultPerAccount(),
    ).thenAnswer((_) async => Success(latestPerAccount));

    final container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(repo),
        accountsProvider.overrideWith(() => _FakeAccountsNotifier(accounts)),
      ],
    );
    addTearDown(container.dispose);

    // Fix the physical viewport so LayoutBuilder picks the intended layout.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CheckInPage()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('narrow layout: tapping a card pushes CheckInAccountDetailPage', (
    tester,
  ) async {
    const accountId = 'acc-narrow';
    final account = _account(id: accountId, name: 'Narrow');
    await pump(
      tester,
      size: const Size(600, 1200),
      accounts: [account],
      tasks: [_task(id: 'task-1', accountId: accountId)],
      latestPerAccount: [_result(accountId: accountId)],
    );

    // Master card is rendered.
    expect(find.byType(CheckInResultCard), findsOneWidget);

    // Tap it — should push the detail page.
    await tester.tap(find.byType(CheckInResultCard));
    await tester.pumpAndSettle();

    // Detail page's AppBar is now on screen.
    expect(find.text('签到记录'), findsOneWidget);
  });

  testWidgets(
    'wide layout: tapping a card updates selectedAccountIdProvider and mounts the detail pane',
    (tester) async {
      const accountId = 'acc-wide';
      final account = _account(id: accountId, name: 'Wide');
      final container = await pump(
        tester,
        size: const Size(1400, 1000),
        accounts: [account],
        tasks: [_task(id: 'task-2', accountId: accountId)],
        latestPerAccount: [_result(accountId: accountId)],
      );

      // Placeholder is shown initially.
      expect(find.text('请在左侧选择一个账号查看签到历史'), findsOneWidget);
      expect(container.read(selectedAccountIdProvider), isNull);

      // Tap the master-list card.
      await tester.tap(find.byType(CheckInResultCard).first);
      await tester.pumpAndSettle();

      expect(container.read(selectedAccountIdProvider), accountId);

      // Detail pane is now mounted — the delete-sweep IconButton belongs
      // to the CheckInDetailView header, so its presence is a good proxy
      // for "detail pane is live".
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'master list filters out results whose account no longer exists (orphan)',
    (tester) async {
      const liveAccountId = 'acc-live';
      // Account list only includes the live one — the orphan is purposely
      // missing. The orphan's check-in result must be dropped by
      // checkInAccountSummariesProvider.
      await pump(
        tester,
        size: const Size(600, 1200),
        accounts: [_account(id: liveAccountId, name: 'Live')],
        tasks: [_task(id: 'task-live', accountId: liveAccountId)],
        latestPerAccount: [
          _result(accountId: liveAccountId, id: 'r-live'),
          _result(accountId: 'acc-ghost', id: 'r-ghost'),
        ],
      );

      final cards = tester
          .widgetList<CheckInResultCard>(find.byType(CheckInResultCard))
          .toList();
      expect(cards, hasLength(1));
      // Sanity: the remaining card is the one tied to the live account.
      expect(cards.single.display.result.accountId, liveAccountId);
    },
  );
}
