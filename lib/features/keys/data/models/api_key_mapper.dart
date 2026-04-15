/// Mapper between [ApiKey] domain entity and persistable [Map].
///
/// Used by local data sources to serialize/deserialize API keys for Hive
/// storage. The actual secret key value is handled separately by [SecureStore].
library;

import '../../domain/entities/api_key.dart';

/// Converts [ApiKey] entities to and from JSON-compatible maps.
class ApiKeyMapper {
  const ApiKeyMapper._();

  /// Serializes an [ApiKey] into a persistable map.
  static Map<String, dynamic> toMap(ApiKey apiKey) => {
    'id': apiKey.id,
    'accountId': apiKey.accountId,
    'name': apiKey.name,
    'quota': apiKey.quota,
    'usedQuota': apiKey.usedQuota,
    'expiresAt': apiKey.expiresAt?.toIso8601String(),
    'createdAt': apiKey.createdAt.toIso8601String(),
    'updatedAt': apiKey.updatedAt.toIso8601String(),
  };

  /// Deserializes a map back into an [ApiKey].
  static ApiKey fromMap(Map<String, dynamic> map) {
    return ApiKey(
      id: map['id'] as String,
      accountId: map['accountId'] as String,
      name: map['name'] as String,
      quota: map['quota'] as int?,
      usedQuota: map['usedQuota'] as int? ?? 0,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
