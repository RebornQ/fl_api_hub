/// Repository contract for [Account] operations.
///
/// This interface defines the domain-level API for account management.
/// Implementations may combine local storage and remote API calls.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/account.dart';

/// Abstract repository for account CRUD operations.
abstract class AccountsRepository {
  /// Returns all accounts.
  Future<Result<List<Account>>> getAll();

  /// Returns a single account by [id].
  Future<Result<Account>> getById(String id);

  /// Creates a new [account]. The access token is embedded in the entity.
  Future<Result<Account>> create(Account account);

  /// Updates an existing [account]. The access token is embedded in the entity.
  Future<Result<Account>> update(Account account);

  /// Deletes an account by [id].
  Future<Result<void>> delete(String id);

  /// Removes a tag reference from every account that currently cites it.
  ///
  /// Called synchronously from the tag feature's delete flow to guarantee
  /// there are no orphan tag ids hanging off accounts. Returns the number
  /// of accounts that were actually modified.
  Future<Result<int>> removeTagFromAllAccounts(String tagId);
}
