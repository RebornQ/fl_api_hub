/// State management for the account list.
///
/// [AccountsNotifier] loads all accounts on first watch and exposes mutation
/// methods (create, update, delete, toggleEnabled). Every mutation performs
/// a pessimistic update — the full list is re-read from the repository after
/// each successful write.
///
/// It also drives periodic reachability checks:
///  * [checkAll] fans out [AccountsRemoteDataSource.fetchAccountInfo] calls
///    to all enabled accounts in batches of 4, updating the cached
///    balance on success and the reachability cache with the outcome.
///  * [checkOne] performs the same cycle for a single account.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/site_status_dto.dart';
import '../../../../core/network/dto/user_info_dto.dart';
import '../../../../core/network/reachability_status.dart';
import '../../../../core/result/result.dart';
import '../../data/datasources/accounts_remote_datasource.dart';
import '../../data/models/account_api_mapper.dart';
import '../../domain/entities/account.dart';
import 'account_reachability_providers.dart';
import 'accounts_providers.dart';

/// Number of parallel checks per batch when scanning all accounts.
const _batchSize = 4;

/// Minimum interval between automatic full scans. Manual refresh bypasses
/// this by passing `force: true`.
const _throttleWindow = Duration(seconds: 30);

/// Manages the async state of the accounts list.
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.getAll();
    return result.when(
      onSuccess: (accounts) => accounts,
      onFailure: (e) => throw e,
    );
  }

  /// Creates a new account and refreshes the list.
  Future<void> create(Account account) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.create(account);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Updates an existing account and refreshes the list.
  Future<void> saveAccount(Account account) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(account);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Deletes an account by [id] and refreshes the list.
  Future<void> delete(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.delete(id);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
        // Remove any lingering reachability cache.
        await ref.read(accountReachabilityMapProvider.notifier).remove(id);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Toggles the enabled state of an account and refreshes the list.
  Future<void> toggleEnabled(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final account = current.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Account $id not found in state'),
    );
    final updated = account.copyWith(
      enabled: !account.enabled,
      updatedAt: DateTime.now(),
    );

    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(updated);
    switch (result) {
      case Success():
        final all = await repo.getAll();
        state = AsyncData(all.dataOrNull ?? []);
        // If the account was just disabled, clear its cached reachability.
        if (!updated.enabled) {
          await ref.read(accountReachabilityMapProvider.notifier).remove(id);
        }
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  // ── Reachability scanning ───────────────────────────────────────────

  /// Runs a reachability check against every enabled account.
  ///
  /// Throttled to once per [_throttleWindow]; pass `force: true` to bypass
  /// (e.g. from pull-to-refresh). Disabled accounts are skipped and their
  /// cached records are purged.
  Future<void> checkAll({bool force = false}) async {
    final lastAt = ref.read(reachabilityThrottleProvider);
    if (!force &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _throttleWindow) {
      return;
    }

    // Make sure the account list has loaded.
    final accounts = await future;
    if (accounts.isEmpty) {
      ref.read(reachabilityThrottleProvider.notifier).stamp();
      return;
    }

    // Purge cache entries for disabled accounts.
    final reachabilityNotifier = ref.read(
      accountReachabilityMapProvider.notifier,
    );
    for (final account in accounts.where((a) => !a.enabled)) {
      await reachabilityNotifier.remove(account.id);
    }

    final targets = accounts.where((a) => a.enabled).toList();
    if (targets.isEmpty) {
      ref.read(reachabilityThrottleProvider.notifier).stamp();
      return;
    }

    final checkingNotifier = ref.read(checkingIdsProvider.notifier);
    checkingNotifier.markChecking(targets.map((a) => a.id));

    try {
      await _runBatched(targets, _batchSize, _checkSingle);
    } finally {
      // Any ids still marked as checking (e.g. after unexpected errors)
      // must be cleared so the UI does not stay in the breathing state.
      checkingNotifier.clear();
      ref.read(reachabilityThrottleProvider.notifier).stamp();
    }
  }

  /// Runs a reachability check for a single account by [id].
  ///
  /// Does nothing if the account does not exist or is disabled.
  Future<void> checkOne(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final account = current.where((a) => a.id == id).firstOrNull;
    if (account == null || !account.enabled) return;

    final checkingNotifier = ref.read(checkingIdsProvider.notifier);
    checkingNotifier.markChecking([id]);
    try {
      await _checkSingle(account);
    } finally {
      checkingNotifier.markDone(id);
    }
  }

  /// Executes [task] against each item in [items], processing at most
  /// [size] items concurrently.
  Future<void> _runBatched<T>(
    List<T> items,
    int size,
    Future<void> Function(T) task,
  ) async {
    for (var i = 0; i < items.length; i += size) {
      final chunk = items.skip(i).take(size).toList();
      await Future.wait(chunk.map(task));
    }
  }

  /// Fetches account info for [account], updates the reachability cache
  /// and persists the refreshed account fields on success.
  ///
  /// Issues [fetchAccountInfo] and [fetchSiteStatus] in parallel. Reachability
  /// is driven purely by the user-info result; a failing status call only
  /// degrades the balance computation to the default quota factor and never
  /// marks the account as unreachable.
  Future<void> _checkSingle(Account account) async {
    final reachabilityNotifier = ref.read(
      accountReachabilityMapProvider.notifier,
    );
    final checkingNotifier = ref.read(checkingIdsProvider.notifier);
    try {
      final remote = ref.read(
        accountsRemoteDataSourceProvider(account.siteType),
      );
      final request = ApiRequest(
        baseUrl: account.baseUrl,
        authToken: account.accessToken,
        authType: account.authType,
        userId: account.userId,
      );

      final results = await Future.wait([
        remote.fetchAccountInfo(request),
        remote.fetchSiteStatus(request),
      ]);
      final userInfoResult = results[0] as Result<UserInfoDto>;
      final statusResult = results[1] as Result<SiteStatusDto>;

      final now = DateTime.now();
      switch (userInfoResult) {
        case Success(:final data):
          await reachabilityNotifier.put(
            account.id,
            ReachabilityRecord.ok(now),
          );
          final quotaPerUnit = _resolveQuotaPerUnit(statusResult);
          await _syncAccountInfo(account, data, quotaPerUnit);
        case Failure(:final exception):
          await reachabilityNotifier.put(
            account.id,
            ReachabilityRecord.fail(now, categorizeFailure(exception)),
          );
      }
    } catch (e) {
      // Defensive: any unexpected error is treated as a network failure.
      await reachabilityNotifier.put(
        account.id,
        ReachabilityRecord.fail(DateTime.now(), categorizeFailure(e)),
      );
    } finally {
      checkingNotifier.markDone(account.id);
    }
  }

  /// Picks the quota → USD factor from [statusResult] when available,
  /// otherwise falls back to [kDefaultQuotaPerUnit].
  double _resolveQuotaPerUnit(Result<SiteStatusDto> statusResult) {
    if (statusResult is Success<SiteStatusDto>) {
      final reported = statusResult.data.quotaPerUnit;
      if (reported != null && reported > 0) return reported;
    }
    return kDefaultQuotaPerUnit;
  }

  /// Merges API-reported user info into [account] and persists the result.
  ///
  /// Only fills sentinel-valued fields (`username == ''`, `userId <= 0`) from
  /// the response — values the user has already entered are preserved even
  /// when the upstream returns them empty. When nothing actually changes the
  /// repository write is skipped to avoid churning `updatedAt`.
  Future<void> _syncAccountInfo(
    Account account,
    UserInfoDto info,
    double quotaPerUnit,
  ) async {
    final derivedBalance = AccountApiMapper.computeBalance(info, quotaPerUnit);

    final reportedUsername = AccountApiMapper.extractUsername(info);
    final nextUsername =
        (reportedUsername != null && reportedUsername.isNotEmpty)
        ? reportedUsername
        : account.username;

    final reportedUserId = AccountApiMapper.extractUserId(info);
    final nextUserId = (reportedUserId != null && reportedUserId > 0)
        ? reportedUserId
        : account.userId;

    final patched = account.copyWith(
      balance: derivedBalance ?? account.balance,
      username: nextUsername,
      userId: nextUserId,
    );

    if (patched.deepEquals(account)) return;

    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(patched);
    if (result is Failure) return;

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final a in current) a.id == patched.id ? patched : a,
    ]);
  }
}
