/// Concrete implementation of [AccountsRepository] backed by local storage.
///
/// Delegates all operations to [AccountsLocalDataSource]. Account data
/// (including access token) is persisted as a single Hive entry.
library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../datasources/accounts_local_datasource.dart';

/// Local-only implementation of [AccountsRepository].
class AccountsRepositoryImpl implements AccountsRepository {
  final AccountsLocalDataSource _local;

  AccountsRepositoryImpl(this._local);

  @override
  Future<Result<List<Account>>> getAll() async {
    try {
      return Success(_local.getAll());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load accounts: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Account>> getById(String id) async {
    try {
      final account = _local.getById(id);
      if (account == null) {
        return const Failure(StorageException(message: 'Account not found'));
      }
      return Success(account);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load account: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Account>> create(Account account) async {
    try {
      await _local.save(account);
      return Success(account);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to create account: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Account>> update(Account account) async {
    try {
      await _local.save(account);
      return Success(account);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to update account: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _local.delete(id);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to delete account: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<int>> removeTagFromAllAccounts(String tagId) async {
    try {
      final accounts = _local.getAll();
      var touched = 0;
      for (final account in accounts) {
        if (!account.tagIds.contains(tagId)) continue;
        final remaining = account.tagIds
            .where((id) => id != tagId)
            .toList(growable: false);
        await _local.save(account.copyWith(tagIds: remaining));
        touched++;
      }
      return Success(touched);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to remove tag $tagId from accounts: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
