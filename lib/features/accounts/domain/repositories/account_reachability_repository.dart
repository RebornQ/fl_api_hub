/// Repository contract for per-account reachability records.
///
/// Unlike [AccountsRepository], this contract does NOT return [Result]:
/// reachability is a presentation-level concern where a missing or
/// malformed record is an acceptable, non-exceptional state. Callers
/// simply get back `null` / an empty map.
library;

import '../../../../core/network/reachability_status.dart';

/// Domain-level API for reading and mutating reachability records.
abstract class AccountReachabilityRepository {
  /// Returns all known records, keyed by account id.
  Map<String, ReachabilityRecord> getAll();

  /// Writes [record] for [accountId], overwriting any previous value.
  Future<void> put(String accountId, ReachabilityRecord record);

  /// Removes any stored record for [accountId].
  Future<void> remove(String accountId);
}
