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

import '../../../../core/network/api_request.dart';
import '../../../../core/network/reachability_status.dart';
import '../../../../core/result/result.dart';
import '../../data/datasources/accounts_remote_datasource.dart';
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
  Future<void> create(Account account, {String? accessToken}) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.create(account, accessToken: accessToken);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Updates an existing account and refreshes the list.
  Future<void> saveAccount(Account account, {String? accessToken}) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(account, accessToken: accessToken);
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
  /// and persists the new balance on success.
  Future<void> _checkSingle(Account account) async {
    final reachabilityNotifier = ref.read(
      accountReachabilityMapProvider.notifier,
    );
    final checkingNotifier = ref.read(checkingIdsProvider.notifier);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      final tokenResult = await repo.getAccessToken(account.id);
      final token = tokenResult.dataOrNull;

      final remote = ref.read(
        accountsRemoteDataSourceProvider(account.siteType),
      );
      final result = await remote.fetchAccountInfo(
        ApiRequest(
          baseUrl: account.baseUrl,
          authToken: token,
          authType: account.authType,
        ),
      );

      final now = DateTime.now();
      switch (result) {
        case Success(:final data):
          await reachabilityNotifier.put(
            account.id,
            ReachabilityRecord.ok(now),
          );
          if (data.balance != null && data.balance != account.balance) {
            await _persistBalance(account, data.balance!);
          }
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

  /// Persists [balance] on [account] without bumping `updatedAt`, then
  /// patches the in-memory list. Does NOT emit [AsyncLoading] so the UI
  /// can update progressively as results stream in.
  Future<void> _persistBalance(Account account, double balance) async {
    final patched = account.copyWith(balance: balance);
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
