/// Concrete implementation of [AccountsRepository].
///
/// Delegates all operations to [AccountsLocalDataSource]. Account metadata
/// is stored in Hive while access tokens are kept in [SecureStore] — both
/// are handled transparently by the data source.
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
  Future<Result<Account>> create(Account account, {String? accessToken}) async {
    try {
      await _local.save(account, accessToken: accessToken);
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
  Future<Result<Account>> update(Account account, {String? accessToken}) async {
    try {
      await _local.save(account, accessToken: accessToken);
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
  Future<Result<String?>> getAccessToken(String accountId) async {
    try {
      final token = await _local.getAccessToken(accountId);
      return Success(token);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to read access token: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }
}
