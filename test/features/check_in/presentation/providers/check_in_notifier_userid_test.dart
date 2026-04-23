/// Unit tests for [CheckInNotifier.executeCheckIn] userId handling.
///
/// Covers three scenarios:
/// 1. Happy path — [Account.userId] > 0 is forwarded as [ApiRequest.userId]
///    so [AuthInterceptor] injects the `New-API-User` header.
/// 2. Sentinel path — [Account.userId] == -1 short-circuits the flow and
///    records a [CheckInStatus.skipped] [CheckInResult] instead of firing
///    a broken request that would always 401.
/// 3. Missing-token guard — stays untouched by the new branch.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_all_api_hub/core/network/api_request.dart';
import 'package:fl_all_api_hub/core/network/dto/check_in_result_dto.dart';
import 'package:fl_all_api_hub/core/network/site_adapter.dart';
import 'package:fl_all_api_hub/core/network/site_type.dart';
import 'package:fl_all_api_hub/core/result/result.dart';
import 'package:fl_all_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_all_api_hub/features/accounts/domain/entities/check_in_config.dart';
import 'package:fl_all_api_hub/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:fl_all_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_all_api_hub/features/check_in/data/datasources/check_in_remote_datasource.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/check_in_result.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/check_in_task.dart';
import 'package:fl_all_api_hub/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:fl_all_api_hub/features/check_in/presentation/providers/check_in_providers.dart';

// ── Test doubles ────────────────────────────────────────────────────

class _MockCheckInRepository extends Mock implements CheckInRepository {}

class _MockAccountsRepository extends Mock implements AccountsRepository {}

class _MockSiteAdapter extends Mock implements SiteAdapter {}

/// Captures [ApiRequest] passed into [checkIn] and returns a canned [Result].
///
/// Extends [CheckInRemoteDataSource] so the notifier can [ref.read] it via
/// [checkInRemoteDataSourceProvider] without touching the real [SiteAdapter].
class _CapturingRemoteDataSource extends CheckInRemoteDataSource {
  _CapturingRemoteDataSource({required Result<CheckInResultDto> stub})
    : _stub = stub,
      super(_MockSiteAdapter());

  final Result<CheckInResultDto> _stub;
  int callCount = 0;
  ApiRequest? lastRequest;

  @override
  Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
    callCount++;
    lastRequest = request;
    return _stub;
  }
}

// ── Fixtures ───────────────────────────────────────────────────────

CheckInTask _task({
  required String id,
  required String accountId,
  bool enabled = true,
}) {
  return CheckInTask(
    id: id,
    accountId: accountId,
    enabled: enabled,
    scheduleTime: '09:00',
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

Account _account({
  required String id,
  String? token,
  int userId = 42,
  bool enabled = true,
  bool autoCheckInEnabled = true,
}) {
  return Account(
    id: id,
    name: 'acc-$id',
    baseUrl: 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    accessToken: token,
    userId: userId,
    enabled: enabled,
    checkIn: CheckInConfig(autoCheckInEnabled: autoCheckInEnabled),
    createdAt: DateTime(2026, 4, 22),
    updatedAt: DateTime(2026, 4, 22),
  );
}

// ── Main ───────────────────────────────────────────────────────────

void main() {
  late _MockCheckInRepository checkInRepo;
  late _MockAccountsRepository accountsRepo;

  setUpAll(() {
    // saveResult / saveTask are called with mock-captured values — register a
    // fallback so mocktail's `any()` matcher is valid for these argument types.
    registerFallbackValue(
      CheckInResult(
        id: 'fallback',
        taskId: 'fallback',
        accountId: 'fallback',
        status: CheckInStatus.skipped,
        executedAt: DateTime(2026, 4, 22),
      ),
    );
    registerFallbackValue(
      CheckInTask(
        id: 'fallback',
        accountId: 'fallback',
        createdAt: DateTime(2026, 4, 22),
        updatedAt: DateTime(2026, 4, 22),
      ),
    );
  });

  setUp(() {
    checkInRepo = _MockCheckInRepository();
    accountsRepo = _MockAccountsRepository();

    // Notifier.build() calls getAllTasks() → return empty list so state
    // resolves without referencing a non-existent task.
    when(
      () => checkInRepo.getAllTasks(),
    ).thenAnswer((_) async => const Success<List<CheckInTask>>([]));
  });

  /// Builds a container wired with mock repositories and the capturing
  /// remote data source for [siteType]. Returns the capturing DS so the
  /// test can inspect the [ApiRequest] that was forwarded (or assert it
  /// was never called).
  ({ProviderContainer container, _CapturingRemoteDataSource capturing})
  buildContainer({
    required SiteType siteType,
    required Result<CheckInResultDto> stub,
  }) {
    final capturing = _CapturingRemoteDataSource(stub: stub);
    final container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(checkInRepo),
        accountsRepositoryProvider.overrideWithValue(accountsRepo),
        checkInRemoteDataSourceProvider(siteType).overrideWithValue(capturing),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, capturing: capturing);
  }

  group('executeCheckIn userId forwarding', () {
    test(
      'forwards positive userId into ApiRequest for the remote call',
      () async {
        // Given
        final task = _task(id: 'task-1', accountId: 'acc-1');
        final account = _account(id: 'acc-1', token: 'tok-abc', userId: 42);
        final fixture = buildContainer(
          siteType: account.siteType,
          stub: const Success<CheckInResultDto>(
            CheckInResultDto(success: true, message: 'ok'),
          ),
        );

        when(
          () => checkInRepo.getTaskById('task-1'),
        ).thenAnswer((_) async => Success<CheckInTask>(task));
        when(
          () => accountsRepo.getById('acc-1'),
        ).thenAnswer((_) async => Success<Account>(account));
        when(() => checkInRepo.saveResult(any())).thenAnswer(
          (inv) async => Success<CheckInResult>(
            inv.positionalArguments[0] as CheckInResult,
          ),
        );
        when(() => checkInRepo.saveTask(any())).thenAnswer(
          (inv) async =>
              Success<CheckInTask>(inv.positionalArguments[0] as CheckInTask),
        );

        // When — wait for build() then execute.
        await fixture.container.read(checkInProvider.future);
        final result = await fixture.container
            .read(checkInProvider.notifier)
            .executeCheckIn('task-1');

        // Then
        expect(fixture.capturing.callCount, 1);
        expect(fixture.capturing.lastRequest?.userId, 42);
        expect(fixture.capturing.lastRequest?.authToken, 'tok-abc');
        expect(fixture.capturing.lastRequest?.baseUrl, account.baseUrl);
        expect(result?.status, CheckInStatus.success);
      },
    );

    test(
      'short-circuits with skipped result when userId == -1 sentinel',
      () async {
        // Given
        final task = _task(id: 'task-2', accountId: 'acc-2');
        final account = _account(id: 'acc-2', token: 'tok-xyz', userId: -1);
        final fixture = buildContainer(
          siteType: account.siteType,
          stub: const Success<CheckInResultDto>(
            CheckInResultDto(success: true, message: 'should-not-be-called'),
          ),
        );

        when(
          () => checkInRepo.getTaskById('task-2'),
        ).thenAnswer((_) async => Success<CheckInTask>(task));
        when(
          () => accountsRepo.getById('acc-2'),
        ).thenAnswer((_) async => Success<Account>(account));

        final savedResults = <CheckInResult>[];
        when(() => checkInRepo.saveResult(any())).thenAnswer((inv) async {
          final r = inv.positionalArguments[0] as CheckInResult;
          savedResults.add(r);
          return Success<CheckInResult>(r);
        });
        when(() => checkInRepo.saveTask(any())).thenAnswer(
          (inv) async =>
              Success<CheckInTask>(inv.positionalArguments[0] as CheckInTask),
        );

        // When
        await fixture.container.read(checkInProvider.future);
        final result = await fixture.container
            .read(checkInProvider.notifier)
            .executeCheckIn('task-2');

        // Then
        expect(
          fixture.capturing.callCount,
          0,
          reason: 'userId sentinel must short-circuit before network call',
        );
        expect(result, isNotNull);
        expect(result!.status, CheckInStatus.skipped);
        expect(result.message, contains('userId'));
        expect(savedResults, hasLength(1));
        expect(savedResults.first.status, CheckInStatus.skipped);
        expect(savedResults.first.taskId, 'task-2');
        expect(savedResults.first.accountId, 'acc-2');
      },
    );

    test(
      'returns null silently when access token is missing (regression)',
      () async {
        // Given
        final task = _task(id: 'task-3', accountId: 'acc-3');
        final account = _account(id: 'acc-3', token: null, userId: 99);
        final fixture = buildContainer(
          siteType: account.siteType,
          stub: const Success<CheckInResultDto>(
            CheckInResultDto(success: true, message: 'should-not-be-called'),
          ),
        );

        when(
          () => checkInRepo.getTaskById('task-3'),
        ).thenAnswer((_) async => Success<CheckInTask>(task));
        when(
          () => accountsRepo.getById('acc-3'),
        ).thenAnswer((_) async => Success<Account>(account));

        // When
        await fixture.container.read(checkInProvider.future);
        final result = await fixture.container
            .read(checkInProvider.notifier)
            .executeCheckIn('task-3');

        // Then
        expect(
          result,
          isNull,
          reason: 'missing token path should not create any result',
        );
        expect(fixture.capturing.callCount, 0);
        verifyNever(() => checkInRepo.saveResult(any()));
        verifyNever(() => checkInRepo.saveTask(any()));
      },
    );
  });
}
