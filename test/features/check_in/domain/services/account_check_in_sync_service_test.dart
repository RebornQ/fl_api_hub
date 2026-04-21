/// Unit tests for [AccountCheckInSyncService].
///
/// Covers the four reconciliation branches plus idempotency:
/// 1. autoCheckInEnabled=true + no task → creates enabled task at 09:00.
/// 2. autoCheckInEnabled=true + disabled task → flips `enabled` to true,
///    preserves scheduleTime / history / lastRunAt.
/// 3. autoCheckInEnabled=false + enabled task → flips `enabled` to false,
///    does NOT delete the task or its historical results.
/// 4. autoCheckInEnabled=false + no task → no writes at all.
/// 5. Two consecutive [sync] calls leave the store in the same state
///    (idempotency) and the second call produces zero write-equivalent
///    transitions in the summary.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/error/app_exception.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/check_in_config.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_task.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/services/account_check_in_sync_service.dart';

// ── Test doubles ────────────────────────────────────────────────────

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockCheckInRepository extends Mock implements CheckInRepository {}

// ── Fixtures ───────────────────────────────────────────────────────

Account _account({
  required String id,
  required bool autoCheckInEnabled,
  SiteType siteType = SiteType.newApi,
}) {
  return Account(
    id: id,
    name: 'acc-$id',
    baseUrl: 'https://$id.example.com',
    siteType: siteType,
    authType: AuthType.accessToken,
    userId: 10,
    checkIn: CheckInConfig(autoCheckInEnabled: autoCheckInEnabled),
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

CheckInTask _task({
  required String id,
  required String accountId,
  required bool enabled,
  String scheduleTime = '20:00',
  DateTime? lastRunAt,
}) {
  return CheckInTask(
    id: id,
    accountId: accountId,
    enabled: enabled,
    scheduleTime: scheduleTime,
    lastRunAt: lastRunAt,
    createdAt: DateTime(2026, 4, 21),
    updatedAt: DateTime(2026, 4, 21),
  );
}

// ── Main ───────────────────────────────────────────────────────────

void main() {
  late _MockAccountsRepository accountsRepo;
  late _MockCheckInRepository checkInRepo;
  late AccountCheckInSyncService service;

  final fixedNow = DateTime(2026, 4, 22, 10, 0, 0);
  var idCounter = 0;

  setUpAll(() {
    registerFallbackValue(
      _task(id: 'fallback', accountId: 'fallback', enabled: false),
    );
  });

  setUp(() {
    accountsRepo = _MockAccountsRepository();
    checkInRepo = _MockCheckInRepository();
    idCounter = 0;
    service = AccountCheckInSyncService(
      accountsRepo: accountsRepo,
      checkInRepo: checkInRepo,
      now: () => fixedNow,
      newId: () {
        idCounter++;
        return 'new-task-$idCounter';
      },
    );

    // Default saveTask stub — just echoes back the task as Success.
    when(() => checkInRepo.saveTask(any())).thenAnswer(
      (inv) async =>
          Success<CheckInTask>(inv.positionalArguments[0] as CheckInTask),
    );
  });

  group('AccountCheckInSyncService.sync', () {
    test(
      'creates a new enabled task at 09:00 when account opts in and has none',
      () async {
        final account = _account(id: 'acc-A', autoCheckInEnabled: true);

        when(
          () => accountsRepo.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));
        when(
          () => checkInRepo.getTasksByAccountId('acc-A'),
        ).thenAnswer((_) async => const Success<List<CheckInTask>>([]));

        final result = await service.sync();

        expect(result, isA<Success<SyncSummary>>());
        final summary = (result as Success<SyncSummary>).data;
        expect(summary.created, 1);
        expect(summary.enabledCount, 0);
        expect(summary.disabledCount, 0);

        final captured = verify(
          () => checkInRepo.saveTask(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final saved = captured.single as CheckInTask;
        expect(saved.id, 'new-task-1');
        expect(saved.accountId, 'acc-A');
        expect(saved.enabled, isTrue);
        expect(saved.scheduleTime, '09:00');
        expect(saved.createdAt, fixedNow);
        expect(saved.updatedAt, fixedNow);
      },
    );

    test(
      're-enables a disabled task and preserves scheduleTime/history',
      () async {
        final account = _account(id: 'acc-B', autoCheckInEnabled: true);
        final lastRun = DateTime(2026, 4, 20, 8, 15);
        final existing = _task(
          id: 'task-B',
          accountId: 'acc-B',
          enabled: false,
          scheduleTime: '22:30',
          lastRunAt: lastRun,
        );

        when(
          () => accountsRepo.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));
        when(
          () => checkInRepo.getTasksByAccountId('acc-B'),
        ).thenAnswer((_) async => Success<List<CheckInTask>>([existing]));

        final result = await service.sync();

        final summary = (result as Success<SyncSummary>).data;
        expect(summary.created, 0);
        expect(summary.enabledCount, 1);
        expect(summary.disabledCount, 0);

        final captured = verify(
          () => checkInRepo.saveTask(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final saved = captured.single as CheckInTask;
        expect(saved.id, 'task-B', reason: 'id must not change');
        expect(saved.enabled, isTrue);
        expect(saved.scheduleTime, '22:30', reason: 'scheduleTime preserved');
        expect(saved.lastRunAt, lastRun, reason: 'history preserved');
        expect(saved.updatedAt, fixedNow);
      },
    );

    test(
      'disables an enabled task when account opts out (no delete)',
      () async {
        final account = _account(id: 'acc-C', autoCheckInEnabled: false);
        final existing = _task(
          id: 'task-C',
          accountId: 'acc-C',
          enabled: true,
          scheduleTime: '07:00',
          lastRunAt: DateTime(2026, 4, 19, 7, 0),
        );

        when(
          () => accountsRepo.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));
        when(
          () => checkInRepo.getTasksByAccountId('acc-C'),
        ).thenAnswer((_) async => Success<List<CheckInTask>>([existing]));

        final result = await service.sync();

        final summary = (result as Success<SyncSummary>).data;
        expect(summary.created, 0);
        expect(summary.enabledCount, 0);
        expect(summary.disabledCount, 1);

        final captured = verify(
          () => checkInRepo.saveTask(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final saved = captured.single as CheckInTask;
        expect(saved.id, 'task-C');
        expect(saved.enabled, isFalse);
        expect(saved.scheduleTime, '07:00');
        expect(
          saved.lastRunAt,
          existing.lastRunAt,
          reason: 'historical lastRunAt untouched',
        );

        // No delete calls.
        verifyNever(() => checkInRepo.deleteTask(any()));
      },
    );

    test('does nothing when account opts out and never had a task', () async {
      final account = _account(id: 'acc-D', autoCheckInEnabled: false);

      when(
        () => accountsRepo.getAll(),
      ).thenAnswer((_) async => Success<List<Account>>([account]));
      when(
        () => checkInRepo.getTasksByAccountId('acc-D'),
      ).thenAnswer((_) async => const Success<List<CheckInTask>>([]));

      final result = await service.sync();

      final summary = (result as Success<SyncSummary>).data;
      expect(summary.created, 0);
      expect(summary.enabledCount, 0);
      expect(summary.disabledCount, 0);

      verifyNever(() => checkInRepo.saveTask(any()));
      verifyNever(() => checkInRepo.deleteTask(any()));
    });

    test(
      'is idempotent: second sync makes no new creations or toggles',
      () async {
        final account = _account(id: 'acc-E', autoCheckInEnabled: true);
        // Simulate post-first-sync state: exactly one enabled task exists.
        final firstSyncTask = _task(
          id: 'task-E',
          accountId: 'acc-E',
          enabled: true,
          scheduleTime: '09:00',
        );

        when(
          () => accountsRepo.getAll(),
        ).thenAnswer((_) async => Success<List<Account>>([account]));
        when(
          () => checkInRepo.getTasksByAccountId('acc-E'),
        ).thenAnswer((_) async => Success<List<CheckInTask>>([firstSyncTask]));

        final result = await service.sync();
        final summary = (result as Success<SyncSummary>).data;

        expect(
          summary.created,
          0,
          reason: 'existing task should not be re-created',
        );
        expect(
          summary.enabledCount,
          1,
          reason: 'counted but without a state change',
        );
        expect(summary.disabledCount, 0);

        // Most important: no saveTask call when the task is already in the
        // desired state.
        verifyNever(() => checkInRepo.saveTask(any()));
      },
    );

    test('handles a mixed account list in one pass', () async {
      final accountA = _account(id: 'acc-A', autoCheckInEnabled: true);
      final accountB = _account(id: 'acc-B', autoCheckInEnabled: true);
      final accountC = _account(id: 'acc-C', autoCheckInEnabled: false);
      final taskB = _task(id: 'task-B', accountId: 'acc-B', enabled: false);
      final taskC = _task(id: 'task-C', accountId: 'acc-C', enabled: true);

      when(() => accountsRepo.getAll()).thenAnswer(
        (_) async => Success<List<Account>>([accountA, accountB, accountC]),
      );
      when(
        () => checkInRepo.getTasksByAccountId('acc-A'),
      ).thenAnswer((_) async => const Success<List<CheckInTask>>([]));
      when(
        () => checkInRepo.getTasksByAccountId('acc-B'),
      ).thenAnswer((_) async => Success<List<CheckInTask>>([taskB]));
      when(
        () => checkInRepo.getTasksByAccountId('acc-C'),
      ).thenAnswer((_) async => Success<List<CheckInTask>>([taskC]));

      final result = await service.sync();
      final summary = (result as Success<SyncSummary>).data;

      expect(summary.created, 1);
      expect(summary.enabledCount, 1);
      expect(summary.disabledCount, 1);

      // Three saveTask writes — one per transition. No deletes.
      verify(() => checkInRepo.saveTask(any())).called(3);
      verifyNever(() => checkInRepo.deleteTask(any()));
    });

    test(
      'surfaces account repository failure as Failure<SyncSummary>',
      () async {
        when(() => accountsRepo.getAll()).thenAnswer(
          (_) async => const Failure<List<Account>>(
            StorageException(message: 'db down'),
          ),
        );

        final result = await service.sync();

        expect(result, isA<Failure<SyncSummary>>());
        verifyNever(() => checkInRepo.saveTask(any()));
      },
    );
  });
}
