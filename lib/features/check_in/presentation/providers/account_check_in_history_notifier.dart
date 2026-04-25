/// Paginated state for a single account's check-in history.
///
/// Exposes:
/// - [accountCheckInHistoryProvider] — family notifier with incremental
///   `loadMore()` and `clearAll()`, used by the detail view's infinite
///   scroll.
/// - [accountCheckInStatsProvider] — family provider that reads the full
///   per-account history (capped at 50) and derives summary stats for the
///   detail view's summary card.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/check_in_result.dart';
import 'check_in_providers.dart';
import 'check_in_request_log_providers.dart';

/// Page size for the account history detail view.
const kCheckInDetailPageSize = 20;

/// Immutable state held by [AccountCheckInHistoryNotifier].
class AccountCheckInHistoryState {
  /// All records loaded so far, newest first.
  final List<CheckInResult> items;

  /// Whether additional pages may exist server-side.
  final bool hasMore;

  /// Offset the next page should request from.
  final int nextOffset;

  /// True while a `loadMore` call is in flight.
  final bool isLoadingMore;

  const AccountCheckInHistoryState({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
    this.isLoadingMore = false,
  });

  /// Empty state used after `clearAll`.
  static const AccountCheckInHistoryState empty = AccountCheckInHistoryState(
    items: [],
    hasMore: false,
    nextOffset: 0,
  );

  AccountCheckInHistoryState copyWith({
    List<CheckInResult>? items,
    bool? hasMore,
    int? nextOffset,
    bool? isLoadingMore,
  }) {
    return AccountCheckInHistoryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Manages paginated check-in history for a single account.
///
/// The family argument is the `accountId`. Data is served from
/// [CheckInRepository.getResultsByAccountIdPaged] in pages of
/// [kCheckInDetailPageSize]. Because the data layer caps history at 50
/// records per account, the list converges in at most three pages.
class AccountCheckInHistoryNotifier
    extends FamilyAsyncNotifier<AccountCheckInHistoryState, String> {
  @override
  Future<AccountCheckInHistoryState> build(String accountId) async {
    final repo = ref.watch(checkInRepositoryProvider);
    final result = await repo.getResultsByAccountIdPaged(
      accountId,
      limit: kCheckInDetailPageSize,
      offset: 0,
    );
    final items = result.dataOrNull ?? const <CheckInResult>[];
    return AccountCheckInHistoryState(
      items: items,
      hasMore: items.length == kCheckInDetailPageSize,
      nextOffset: items.length,
    );
  }

  /// Fetches the next page and appends it. Idempotent when already loading
  /// or when there are no more pages.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));

    final repo = ref.read(checkInRepositoryProvider);
    final result = await repo.getResultsByAccountIdPaged(
      arg,
      limit: kCheckInDetailPageSize,
      offset: current.nextOffset,
    );
    final nextItems = result.dataOrNull ?? const <CheckInResult>[];

    state = AsyncData(
      AccountCheckInHistoryState(
        items: [...current.items, ...nextItems],
        hasMore: nextItems.length == kCheckInDetailPageSize,
        nextOffset: current.nextOffset + nextItems.length,
      ),
    );
  }

  /// Deletes every record for this account, resets state, and invalidates
  /// downstream providers so the master list refreshes.
  Future<void> clearAll() async {
    final repo = ref.read(checkInRepositoryProvider);
    await repo.deleteAllResultsByAccountId(arg);

    ref.invalidate(latestResultPerAccountProvider);
    ref.invalidate(accountCheckInStatsProvider(arg));
    ref.invalidate(allPersistedRequestLogsProvider);

    state = const AsyncData(AccountCheckInHistoryState.empty);
  }
}

/// Family notifier for a single account's paginated check-in history.
final accountCheckInHistoryProvider =
    AsyncNotifierProvider.family<
      AccountCheckInHistoryNotifier,
      AccountCheckInHistoryState,
      String
    >(AccountCheckInHistoryNotifier.new);

/// Aggregate stats derived from a single account's check-in history.
class AccountCheckInStats {
  final int totalCount;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final DateTime? lastExecutedAt;

  const AccountCheckInStats({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    this.lastExecutedAt,
  });

  /// Empty stats used when an account has no records.
  static const AccountCheckInStats empty = AccountCheckInStats(
    totalCount: 0,
    successCount: 0,
    failedCount: 0,
    skippedCount: 0,
  );

  /// Reduces a list of results (expected newest-first) into summary stats.
  factory AccountCheckInStats.from(List<CheckInResult> results) {
    if (results.isEmpty) return AccountCheckInStats.empty;

    var success = 0;
    var failed = 0;
    var skipped = 0;
    for (final r in results) {
      switch (r.status) {
        case CheckInStatus.success:
          success++;
        case CheckInStatus.failed:
          failed++;
        case CheckInStatus.skipped:
          skipped++;
        case CheckInStatus.alreadyChecked:
          success++;
      }
    }

    return AccountCheckInStats(
      totalCount: results.length,
      successCount: success,
      failedCount: failed,
      skippedCount: skipped,
      lastExecutedAt: results.first.executedAt,
    );
  }
}

/// Stats derived from the account's full capped history (≤ 50 records).
///
/// Used by the detail view's top summary card. Independent from the
/// paginated [accountCheckInHistoryProvider] so that the card remains
/// accurate even before the user scrolls all pages into memory.
final accountCheckInStatsProvider =
    FutureProvider.family<AccountCheckInStats, String>((ref, accountId) async {
      final repo = ref.watch(checkInRepositoryProvider);
      // The data layer caps retention at 50 per account, so pulling the
      // full history in one shot is cheap and bounded.
      final result = await repo.getResultsByAccountIdPaged(
        accountId,
        limit: 50,
        offset: 0,
      );
      return AccountCheckInStats.from(result.dataOrNull ?? const []);
    });
