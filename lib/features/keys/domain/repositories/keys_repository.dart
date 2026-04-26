/// Repository contract for [ApiKey] operations.
///
/// This interface defines the domain-level API for API key management.
/// Implementations combine remote API calls with local caching.
/// All methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/api_key.dart';

/// Abstract repository for API key CRUD operations.
abstract class KeysRepository {
  /// Returns all API keys for a given [accountId].
  ///
  /// When remote is available, fetches from server and updates local cache.
  /// Falls back to local cache on remote failure.
  Future<Result<List<ApiKey>>> getByAccountId(String accountId);

  /// Returns a single API key by [id].
  Future<Result<ApiKey>> getById(String id);

  /// Creates a new [apiKey] on the remote server and caches locally.
  ///
  /// The server assigns the id and key value. The returned [ApiKey] reflects
  /// the server response, not the input entity.
  Future<Result<ApiKey>> create(ApiKey apiKey);

  /// Updates an existing [apiKey] on the remote server and caches locally.
  Future<Result<ApiKey>> update(ApiKey apiKey);

  /// Deletes an API key by [id] from the remote server and local cache.
  Future<Result<void>> delete(String id);

  /// Resolves a masked token key to the full key value.
  ///
  /// Calls the hidden `POST /api/token/{id}/key` endpoint and updates the
  /// local cache with the full key value.
  Future<Result<ApiKey>> resolveKey(String keyId, String accountId);
}
