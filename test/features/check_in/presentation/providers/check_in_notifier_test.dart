import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/error/app_exception.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/repositories/accounts_repository.dart';
import 'package:all_api_hub_flutter/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_task.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/repositories/check_in_repository.dart';
import 'package:all_api_hub_flutter/features/check_in/presentation/providers/check_in_providers.dart';

class MockCheckInRepository extends Mock implements CheckInRepository {}

class MockAccountsRepository extends Mock implements AccountsRepository {}

void main() {
  late MockCheckInRepository mockCheckInRepo;
  late MockAccountsRepository mockAccountsRepo;
  late ProviderContainer container;

  final enabledTask = CheckInTask(
    id: 'task-1',
    accountId: 'acc-1',
    enabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final disabledTask = CheckInTask(
    id: 'task-2',
    accountId: 'acc-1',
    enabled: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final disabledAccount = Account(
    id: 'acc-1',
    name: 'Disabled Account',
    baseUrl: 'https://disabled.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(
      CheckInResult(
        id: 'fallback',
        taskId: 'fallback',
        accountId: 'fallback',
        status: CheckInStatus.skipped,
        executedAt: DateTime(2026, 1, 1),
      ),
    );
    registerFallbackValue(enabledTask);
  });

  setUp(() {
    mockCheckInRepo = MockCheckInRepository();
    mockAccountsRepo = MockAccountsRepository();

    // Default stub for CheckInNotifier.build().
    when(
      () => mockCheckInRepo.getAllTasks(),
    ).thenAnswer((_) async => const Success(<CheckInTask>[]));

    container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(mockCheckInRepo),
        accountsRepositoryProvider.overrideWithValue(mockAccountsRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CheckInNotifier.executeCheckIn', () {
    test(
      'returns null and does NOT save a result when the account is disabled',
      () async {
        // Make sure build() resolves before we invoke executeCheckIn.
        await container.read(checkInProvider.future);

        when(
          () => mockCheckInRepo.getTaskById('task-1'),
        ).thenAnswer((_) async => Success(enabledTask));
        when(
          () => mockAccountsRepo.getById('acc-1'),
        ).thenAnswer((_) async => Success(disabledAccount));

        final result = await container
            .read(checkInProvider.notifier)
            .executeCheckIn('task-1');

        expect(result, isNull);

        // Core regression assertion: disabled accounts must not produce any
        // history entries. The flow stops BEFORE the token lookup and the
        // remote call, and NO CheckInResult is persisted.
        verifyNever(() => mockCheckInRepo.saveResult(any()));
      },
    );

    test('returns null when the task is missing', () async {
      await container.read(checkInProvider.future);

      // dataOrNull is null when the repository returns Failure.
      when(() => mockCheckInRepo.getTaskById('missing')).thenAnswer(
        (_) async => const Failure(StorageException(message: 'task not found')),
      );

      final result = await container
          .read(checkInProvider.notifier)
          .executeCheckIn('missing');

      expect(result, isNull);
      verifyNever(() => mockAccountsRepo.getById(any()));
      verifyNever(() => mockCheckInRepo.saveResult(any()));
    });

    test('returns null when the task is disabled', () async {
      await container.read(checkInProvider.future);

      when(
        () => mockCheckInRepo.getTaskById('task-2'),
      ).thenAnswer((_) async => Success(disabledTask));

      final result = await container
          .read(checkInProvider.notifier)
          .executeCheckIn('task-2');

      expect(result, isNull);
      // Disabled task short-circuits before touching the accounts repo.
      verifyNever(() => mockAccountsRepo.getById(any()));
      verifyNever(() => mockCheckInRepo.saveResult(any()));
    });
  });
}
