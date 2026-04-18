/// Repository contract for [ApiKey] operations.
///
/// This interface defines the domain-level API for API key management.
/// Implementations may combine local storage and remote API calls.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/api_key.dart';

/// Abstract repository for API key CRUD operations.
abstract class KeysRepository {
  /// Returns all API keys for a given [accountId].
  Future<Result<List<ApiKey>>> getByAccountId(String accountId);

  /// Returns a single API key by [id].
  Future<Result<ApiKey>> getById(String id);

  /// Creates a new [apiKey]. The secret value is embedded in the entity.
  Future<Result<ApiKey>> create(ApiKey apiKey);

  /// Updates an existing [apiKey]. The secret value is embedded in the entity.
  Future<Result<ApiKey>> update(ApiKey apiKey);

  /// Deletes an API key by [id].
  Future<Result<void>> delete(String id);
}
