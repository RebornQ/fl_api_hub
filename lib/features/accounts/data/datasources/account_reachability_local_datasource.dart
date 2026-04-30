/// Local data source for per-account reachability status.
///
/// Stores [ReachabilityRecord]s in a dedicated Hive box keyed by
/// `accountId`. This box is separate from the [Account] box so the domain
/// entity stays free of UI-specific status fields and Hive migrations
/// remain isolated.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../../../core/network/reachability_status.dart';

/// Box name for reachability records.
const reachabilityBoxName = 'account_reachability';

/// CRUD over the reachability Hive box.
class AccountReachabilityLocalDataSource {
  final Box _box;

  AccountReachabilityLocalDataSource(this._box);

  /// Returns all stored records, keyed by account id. Malformed entries
  /// are silently skipped.
  Map<String, ReachabilityRecord> getAll() {
    final result = <String, ReachabilityRecord>{};
    for (final key in _box.keys) {
      if (key is! String) continue;
      final raw = _box.get(key);
      if (raw is! Map) continue;
      final record = ReachabilityRecord.fromMap(Map<String, dynamic>.from(raw));
      if (record != null) result[key] = record;
    }
    return result;
  }

  /// Writes [record] for [accountId].
  Future<void> put(String accountId, ReachabilityRecord record) {
    return _box.put(accountId, record.toMap());
  }

  /// Removes the record for [accountId], if any.
  Future<void> remove(String accountId) => _box.delete(accountId);
}

/// Riverpod provider for [AccountReachabilityLocalDataSource].
///
/// Assumes `initHive()` has opened the [reachabilityBoxName] box.
final accountReachabilityLocalDataSourceProvider =
    Provider<AccountReachabilityLocalDataSource>((ref) {
      return AccountReachabilityLocalDataSource(Hive.box(reachabilityBoxName));
    });
