import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/scheduler/check_in_scheduler_service.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/check_in_result.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/check_in_task.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/scheduler_config.dart';
import 'package:fl_api_hub/features/check_in/presentation/providers/check_in_providers.dart';
import 'package:fl_api_hub/features/check_in/presentation/providers/scheduler_config_notifier.dart';

/// Records [executeCheckIn] calls without touching repositories or the
/// network. Its [build] seeds the provider state synchronously (via a
/// resolved future) so the scheduler sees the task list on the first tick.
class FakeCheckInNotifier extends CheckInNotifier {
  FakeCheckInNotifier(this._initialTasks);

  final List<CheckInTask> _initialTasks;

  /// Task ids captured from each scheduler-driven execution.
  final List<String> executedIds = [];

  @override
  Future<List<CheckInTask>> build() async => _initialTasks;

  @override
  Future<CheckInResult?> executeCheckIn(String taskId) async {
    executedIds.add(taskId);
    return null;
  }
}

/// Fake accounts notifier: returns a preconfigured list and no-ops for
/// reachability scans so [AccountsPage] style side-effects don't leak in.
class FakeAccountsNotifier extends AccountsNotifier {
  FakeAccountsNotifier(this._initialAccounts);

  final List<Account> _initialAccounts;

  @override
  Future<List<Account>> build() async => _initialAccounts;

  @override
  Future<void> checkAll({bool force = false}) async {}

  @override
  Future<void> checkOne(String id) async {}
}

/// Fake scheduler config notifier that avoids Hive by returning a constant
/// config from [build].
class FakeSchedulerConfigNotifier extends SchedulerConfigNotifier {
  FakeSchedulerConfigNotifier(this._config);

  final SchedulerConfig _config;

  @override
  SchedulerConfig build() => _config;
}

/// Helper to build an [Account] with minimal ceremony.
Account _account({required String id, required bool enabled}) {
  return Account(
    id: id,
    name: id,
    baseUrl: 'https://$id.example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    enabled: enabled,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

/// Helper to build a [CheckInTask] bound to a given account.
CheckInTask _task({
  required String id,
  required String accountId,
  bool enabled = true,
}) {
  return CheckInTask(
    id: id,
    accountId: accountId,
    enabled: enabled,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  /// Builds a ProviderContainer with all the fake notifiers needed to drive
  /// the scheduler without touching Hive, the network, or real repositories.
  ({
    ProviderContainer container,
    FakeCheckInNotifier fakeCheckIn,
    Provider<CheckInSchedulerService> serviceProvider,
  })
  buildFixture({
    required List<CheckInTask> tasks,
    required List<Account> accounts,
  }) {
    final fakeCheckIn = FakeCheckInNotifier(tasks);
    final fakeAccounts = FakeAccountsNotifier(accounts);
    final fakeConfig = FakeSchedulerConfigNotifier(
      const SchedulerConfig(
        enabled: true,
        // Full-day window so the wall-clock `DateTime.now()` used by the
        // production code always qualifies.
        timeWindowStart: '00:00',
        timeWindowEnd: '23:59',
      ),
    );

    // Inline provider that hands the container's [Ref] to the service. We
    // avoid editing lib/ to expose this publicly.
    final serviceProvider = Provider<CheckInSchedulerService>((ref) {
      return CheckInSchedulerService(ref);
    });

    final container = ProviderContainer(
      overrides: [
        checkInProvider.overrideWith(() => fakeCheckIn),
        accountsProvider.overrideWith(() => fakeAccounts),
        schedulerConfigProvider.overrideWith(() => fakeConfig),
      ],
    );

    return (
      container: container,
      fakeCheckIn: fakeCheckIn,
      serviceProvider: serviceProvider,
    );
  }

  group('CheckInSchedulerService._getDueTasks filter', () {
    test('skips tasks whose account is disabled, runs the rest', () {
      fakeAsync((async) {
        final fixture = buildFixture(
          tasks: [
            _task(id: 'task-a', accountId: 'acc-enabled'),
            _task(id: 'task-b', accountId: 'acc-disabled'),
          ],
          accounts: [
            _account(id: 'acc-enabled', enabled: true),
            _account(id: 'acc-disabled', enabled: false),
          ],
        );

        // Pre-warm the async providers so their [build] futures resolve
        // before the first tick reads `valueOrNull`.
        fixture.container.read(checkInProvider);
        fixture.container.read(accountsProvider);
        async.flushMicrotasks();

        final service = fixture.container.read(fixture.serviceProvider);
        service.start();

        // One full tick interval.
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();

        service.stop();
        fixture.container.dispose();

        expect(fixture.fakeCheckIn.executedIds, ['task-a']);
      });
    });

    test('when every account is disabled, no task is executed on tick', () {
      fakeAsync((async) {
        final fixture = buildFixture(
          tasks: [
            _task(id: 'task-a', accountId: 'acc-1'),
            _task(id: 'task-b', accountId: 'acc-2'),
          ],
          accounts: [
            _account(id: 'acc-1', enabled: false),
            _account(id: 'acc-2', enabled: false),
          ],
        );

        fixture.container.read(checkInProvider);
        fixture.container.read(accountsProvider);
        async.flushMicrotasks();

        final service = fixture.container.read(fixture.serviceProvider);
        service.start();

        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();

        service.stop();
        fixture.container.dispose();

        expect(fixture.fakeCheckIn.executedIds, isEmpty);
      });
    });
  });
}
