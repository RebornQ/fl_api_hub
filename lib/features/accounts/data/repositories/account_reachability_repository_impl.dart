/// Hive-backed implementation of [AccountReachabilityRepository].
library;

import '../../../../core/network/reachability_status.dart';
import '../../domain/repositories/account_reachability_repository.dart';
import '../datasources/account_reachability_local_datasource.dart';

class AccountReachabilityRepositoryImpl
    implements AccountReachabilityRepository {
  final AccountReachabilityLocalDataSource _local;

  AccountReachabilityRepositoryImpl(this._local);

  @override
  Map<String, ReachabilityRecord> getAll() => _local.getAll();

  @override
  Future<void> put(String accountId, ReachabilityRecord record) =>
      _local.put(accountId, record);

  @override
  Future<void> remove(String accountId) => _local.remove(accountId);
}
