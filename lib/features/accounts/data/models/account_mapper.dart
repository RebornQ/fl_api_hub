/// Mapper between [Account] domain entity and persistable [Map].
///
/// Used by local data sources to serialize/deserialize accounts for Hive
/// storage. Enum values are stored as strings for forward compatibility.
library;

import '../../../../core/network/site_type.dart';
import '../../domain/entities/account.dart';

/// Converts [Account] entities to and from JSON-compatible maps.
class AccountMapper {
  const AccountMapper._();

  /// Serializes an [Account] into a persistable map.
  static Map<String, dynamic> toMap(Account account) => {
    'id': account.id,
    'name': account.name,
    'baseUrl': account.baseUrl,
    'siteType': account.siteType.value,
    'authType': account.authType.name,
    'enabled': account.enabled,
    'notes': account.notes,
    'balance': account.balance,
    'createdAt': account.createdAt.toIso8601String(),
    'updatedAt': account.updatedAt.toIso8601String(),
  };

  /// Deserializes a map back into an [Account].
  ///
  /// Throws [ArgumentError] if [siteType] value is unrecognized.
  static Account fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['baseUrl'] as String,
      siteType: SiteType.fromValue(map['siteType'] as String),
      authType: AuthType.values.firstWhere(
        (e) => e.name == (map['authType'] as String),
      ),
      enabled: map['enabled'] as bool? ?? true,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
