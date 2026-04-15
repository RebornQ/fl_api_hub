/// Repository contract for [Account] operations.
///
/// This interface defines the domain-level API for account management.
/// Implementations may combine local storage and remote API calls.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/account.dart';

/// Abstract repository for account CRUD and credential access.
abstract class AccountsRepository {
  /// Returns all accounts.
  Future<Result<List<Account>>> getAll();

  /// Returns a single account by [id].
  Future<Result<Account>> getById(String id);

  /// Creates a new account.
  ///
  /// [accessToken] is stored securely alongside the account.
  Future<Result<Account>> create(Account account, {String? accessToken});

  /// Updates an existing account.
  ///
  /// If [accessToken] is provided, the stored token is updated.
  /// Pass `null` explicitly to clear the stored token.
  Future<Result<Account>> update(Account account, {String? accessToken});

  /// Deletes an account and its associated access token.
  Future<Result<void>> delete(String id);

  /// Retrieves the securely stored access token for [accountId].
  Future<Result<String?>> getAccessToken(String accountId);
}
