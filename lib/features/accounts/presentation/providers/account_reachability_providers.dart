/// Riverpod providers for per-account website reachability state.
///
/// This layer exposes three concerns:
///  * [accountReachabilityRepositoryProvider] — CRUD over the Hive cache.
///  * [accountReachabilityMapProvider] — in-memory snapshot keyed by
///    accountId, hydrated from Hive on first read and mutated via its
///    notifier. The account list UI watches this to color the status dot.
///  * [checkingIdsProvider] — the set of account ids currently mid-check.
///    Drives the breathing animation on the dot.
///  * [reachabilityThrottleProvider] — timestamp of the last full-scan
///    check. Used by `AccountsNotifier.checkAll` to suppress duplicate
///    scans triggered by rapid page re-entry.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/reachability_status.dart';
import '../../data/datasources/account_reachability_local_datasource.dart';
import '../../data/repositories/account_reachability_repository_impl.dart';
import '../../domain/repositories/account_reachability_repository.dart';

/// Provides the repository implementation.
final accountReachabilityRepositoryProvider =
    Provider<AccountReachabilityRepository>((ref) {
      return AccountReachabilityRepositoryImpl(
        ref.watch(accountReachabilityLocalDataSourceProvider),
      );
    });

/// In-memory snapshot of reachability records, keyed by account id.
///
/// On first watch the state is hydrated from Hive. Mutations go through
/// [ReachabilityMapNotifier.put] / [ReachabilityMapNotifier.remove] which
/// write-through to Hive and update the snapshot reactively.
class ReachabilityMapNotifier
    extends Notifier<Map<String, ReachabilityRecord>> {
  @override
  Map<String, ReachabilityRecord> build() {
    return ref.read(accountReachabilityRepositoryProvider).getAll();
  }

  /// Updates the record for [accountId] and persists it.
  Future<void> put(String accountId, ReachabilityRecord record) async {
    await ref
        .read(accountReachabilityRepositoryProvider)
        .put(accountId, record);
    state = {...state, accountId: record};
  }

  /// Clears the record for [accountId] and persists the removal.
  Future<void> remove(String accountId) async {
    await ref.read(accountReachabilityRepositoryProvider).remove(accountId);
    if (!state.containsKey(accountId)) return;
    final next = Map<String, ReachabilityRecord>.from(state)..remove(accountId);
    state = next;
  }
}

/// Provider exposing the [ReachabilityMapNotifier] state.
final accountReachabilityMapProvider =
    NotifierProvider<ReachabilityMapNotifier, Map<String, ReachabilityRecord>>(
      ReachabilityMapNotifier.new,
    );

/// The set of account ids currently being checked. Drives the breathing
/// dot animation in `AccountCard`.
class CheckingIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  /// Marks [ids] as currently-checking.
  void markChecking(Iterable<String> ids) {
    if (ids.isEmpty) return;
    state = {...state, ...ids};
  }

  /// Removes [id] from the checking set.
  void markDone(String id) {
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
  }

  /// Clears the entire set. Use after a scan completes or is aborted.
  void clear() {
    if (state.isEmpty) return;
    state = const <String>{};
  }
}

/// Provider exposing the [CheckingIdsNotifier] state.
final checkingIdsProvider = NotifierProvider<CheckingIdsNotifier, Set<String>>(
  CheckingIdsNotifier.new,
);

/// Holds the timestamp of the most recent full-scan check. `null` means
/// no scan has run this session.
class ReachabilityThrottleNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Records that a scan just completed at [at] (defaults to `now`).
  void stamp([DateTime? at]) {
    state = at ?? DateTime.now();
  }
}

/// Provider exposing the last-scan timestamp.
final reachabilityThrottleProvider =
    NotifierProvider<ReachabilityThrottleNotifier, DateTime?>(
      ReachabilityThrottleNotifier.new,
    );
