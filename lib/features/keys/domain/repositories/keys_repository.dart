/// Repository contract for [ApiKey] operations.
///
/// This interface defines the domain-level API for API key management.
/// Implementations may combine local storage and remote API calls.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/api_key.dart';

/// Abstract repository for API key CRUD and secret value access.
abstract class KeysRepository {
  /// Returns all API keys for a given [accountId].
  Future<Result<List<ApiKey>>> getByAccountId(String accountId);

  /// Returns a single API key by [id].
  Future<Result<ApiKey>> getById(String id);

  /// Creates a new API key.
  ///
  /// [keyValue] (the actual secret) is stored securely.
  Future<Result<ApiKey>> create(ApiKey apiKey, {String? keyValue});

  /// Updates an existing API key.
  ///
  /// If [keyValue] is provided, the stored secret is updated.
  Future<Result<ApiKey>> update(ApiKey apiKey, {String? keyValue});

  /// Deletes an API key and its associated secret value.
  Future<Result<void>> delete(String id);

  /// Retrieves the securely stored secret key value for [keyId].
  Future<Result<String?>> getKeyValue(String keyId);
}
