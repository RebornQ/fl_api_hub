/// State management for check-in tasks and execution.
///
/// [CheckInNotifier] manages the task list and provides the [executeCheckIn]
/// method that orchestrates the full check-in flow:
/// task → account → token → remote API → save result → update task.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../data/datasources/check_in_remote_datasource.dart';
import '../../data/models/check_in_api_mapper.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import 'check_in_providers.dart';

/// SiteTypes whose check-in REST protocol is not yet implemented in this
/// app. Accounts carrying one of these types will still appear in the
/// task list (when they opt into auto-check-in via [CheckInConfig]) but
/// their execution is short-circuited with a [CheckInStatus.skipped]
/// result so the user sees a clear "暂不支持" message.
const _unsupportedSiteTypes = <SiteType>{
  SiteType.anyrouter,
  SiteType.wongGongyi,
  SiteType.sub2api,
};

/// Manages the async state of the check-in task list.
class CheckInNotifier extends AsyncNotifier<List<CheckInTask>> {
  @override
  Future<List<CheckInTask>> build() async {
    final repo = ref.read(checkInRepositoryProvider);
    final result = await repo.getAllTasks();
    return result.when(onSuccess: (tasks) => tasks, onFailure: (e) => throw e);
  }

  /// Creates or updates a [CheckInTask] and refreshes the list.
  Future<void> saveTask(CheckInTask task) async {
    state = const AsyncLoading();
    final repo = ref.read(checkInRepositoryProvider);
    final result = await repo.saveTask(task);
    switch (result) {
      case Success():
        await _refreshTasks();
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Deletes a task by [id] and refreshes the list.
  Future<void> deleteTask(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(checkInRepositoryProvider);
    final result = await repo.deleteTask(id);
    switch (result) {
      case Success():
        await _refreshTasks();
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Toggles the enabled state of a task and refreshes the list.
  Future<void> toggleEnabled(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final task = current.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('Task $id not found in state'),
    );
    final updated = task.copyWith(
      enabled: !task.enabled,
      updatedAt: DateTime.now(),
    );

    state = const AsyncLoading();
    final repo = ref.read(checkInRepositoryProvider);
    final result = await repo.saveTask(updated);
    switch (result) {
      case Success():
        await _refreshTasks();
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Executes a manual check-in for the given [taskId].
  ///
  /// Orchestrates the full flow:
  /// 1. Load task → load account → load token.
  /// 2. Build [ApiRequest] and call the remote API.
  /// 3. Map the response DTO to a [CheckInResult] entity.
  /// 4. Save the result and update the task's [lastRunAt].
  /// 5. Refresh the task list state.
  ///
  /// Returns the [CheckInResult] on success (including API-level failures),
  /// or `null` if a precondition failed (disabled task, missing account/token).
  Future<CheckInResult?> executeCheckIn(String taskId) async {
    final checkInRepo = ref.read(checkInRepositoryProvider);
    final accountsRepo = ref.read(accountsRepositoryProvider);

    // 1. Load the task.
    final taskResult = await checkInRepo.getTaskById(taskId);
    final task = taskResult.dataOrNull;
    if (task == null) return null;

    if (!task.enabled) return null;

    // 2. Load the account.
    final accountResult = await accountsRepo.getById(task.accountId);
    final account = accountResult.dataOrNull;
    if (account == null) return null;

    // Silently skip disabled accounts — no history record is produced, so
    // automatic schedulers won't flood the timeline with "skipped" entries.
    if (!account.enabled) return null;

    // 3. Read the access token from the account entity.
    final token = account.accessToken;
    if (token == null || token.isEmpty) return null;

    // 3a. Unsupported site type guard. When the sync service creates tasks
    // for accounts whose SiteType still lacks a check-in adapter
    // (AnyRouter / Wong / Sub2API as of Apr 2026), executing them would
    // misroute to the CommonApiAdapter. Record a skipped result instead
    // so the user knows the request wasn't silently dropped.
    if (_unsupportedSiteTypes.contains(account.siteType)) {
      final now = DateTime.now();
      final result = CheckInResult(
        id: const Uuid().v4(),
        taskId: task.id,
        accountId: task.accountId,
        status: CheckInStatus.skipped,
        message: '${account.siteType.displayName} 站点暂不支持自动签到',
        executedAt: now,
      );
      await checkInRepo.saveResult(result);
      await checkInRepo.saveTask(task.copyWith(lastRunAt: now, updatedAt: now));
      await _refreshTasks();
      return result;
    }

    // 3b. userId sentinel: account snapshot hasn't been hydrated via
    // /api/user/self yet (default sentinel is -1). Strict New-API backends
    // require the `New-API-User` header, so firing a request here would
    // always fail. Record a skipped result instead so the user sees a
    // concrete prompt to refresh the account in the detail page.
    if (account.userId <= 0) {
      final now = DateTime.now();
      final result = CheckInResult(
        id: const Uuid().v4(),
        taskId: task.id,
        accountId: task.accountId,
        status: CheckInStatus.skipped,
        message: '账号缺少 userId,请先在账号详情页刷新/补全账号信息',
        executedAt: now,
      );
      await checkInRepo.saveResult(result);
      await checkInRepo.saveTask(task.copyWith(lastRunAt: now, updatedAt: now));
      await _refreshTasks();
      return result;
    }

    // 4. Build the request.
    final request = ApiRequest(
      baseUrl: account.baseUrl,
      authToken: token,
      authType: account.authType,
      userId: account.userId,
    );

    // 5. Call the remote API.
    final remoteDs = ref.read(
      checkInRemoteDataSourceProvider(account.siteType),
    );
    final apiResult = await remoteDs.checkIn(request);

    // 6–7. Handle response.
    final now = DateTime.now();
    final resultId = const Uuid().v4();

    return apiResult.when(
      onSuccess: (dto) async {
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: task.id,
          accountId: task.accountId,
          resultId: resultId,
        );

        await checkInRepo.saveResult(result);

        // Update task's lastRunAt.
        final updatedTask = task.copyWith(lastRunAt: now, updatedAt: now);
        await checkInRepo.saveTask(updatedTask);
        await _refreshTasks();

        return result;
      },
      onFailure: (exception) async {
        // Save a failed result for traceability.
        final result = CheckInResult(
          id: resultId,
          taskId: task.id,
          accountId: task.accountId,
          status: CheckInStatus.failed,
          message: exception.message,
          executedAt: now,
        );
        await checkInRepo.saveResult(result);

        final updatedTask = task.copyWith(lastRunAt: now, updatedAt: now);
        await checkInRepo.saveTask(updatedTask);
        await _refreshTasks();

        return result;
      },
    );
  }

  /// Re-reads all tasks from the repository and updates the state.
  Future<void> _refreshTasks() async {
    final result = await ref.read(checkInRepositoryProvider).getAllTasks();
    state = result.when(
      onSuccess: (tasks) => AsyncData(tasks),
      onFailure: (e) => AsyncError(e, StackTrace.current),
    );
  }

  /// Executes check-in for all enabled tasks with a concurrency pool of 5.
  ///
  /// Returns the list of [CheckInResult]s from all executions.
  /// Individual failures do not prevent other tasks from running.
  ///
  /// Before dispatching, this reconciles the task list with each account's
  /// [CheckInConfig.autoCheckInEnabled] switch (idempotent upsert) so the
  /// batch reflects the user's current intent even when tasks were never
  /// created manually. The sync is non-destructive — disabled accounts
  /// keep their historical tasks and results; only the `enabled` flag is
  /// toggled.
  Future<List<CheckInResult?>> executeAll() async {
    // 1. Reconcile tasks against the current account list. Failures here
    //    fall through gracefully — we still run whatever task state is
    //    currently in the store.
    await ref.read(accountCheckInSyncServiceProvider).sync();

    // 2. Re-read tasks so the notifier state reflects any newly created /
    //    toggled rows before we pick winners for this batch.
    await _refreshTasks();

    final tasks = state.valueOrNull ?? [];
    final enabled = tasks.where((t) => t.enabled).toList();
    final results = <CheckInResult?>[];

    // Process in chunks of 5 for concurrency control.
    for (var i = 0; i < enabled.length; i += 5) {
      final chunk = enabled.skip(i).take(5);
      final chunkResults = await Future.wait(
        chunk.map((t) => executeCheckIn(t.id)),
      );
      results.addAll(chunkResults);
    }

    // Invalidate results provider so dashboard refreshes.
    ref.invalidate(allCheckInResultsProvider);

    return results;
  }

  /// Executes check-in for specific tasks identified by [taskIds].
  ///
  /// Used by the scheduler service to execute only due tasks,
  /// not all enabled tasks. Maintains the same concurrency pool of 5.
  Future<List<CheckInResult?>> executeAllDue(List<String> taskIds) async {
    final results = <CheckInResult?>[];

    for (var i = 0; i < taskIds.length; i += 5) {
      final chunk = taskIds.skip(i).take(5);
      final chunkResults = await Future.wait(
        chunk.map((id) => executeCheckIn(id)),
      );
      results.addAll(chunkResults);
    }

    ref.invalidate(allCheckInResultsProvider);

    return results;
  }
}
