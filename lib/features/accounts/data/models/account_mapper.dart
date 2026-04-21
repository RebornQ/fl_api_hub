/// Mapper between [Account] domain entity and persistable [Map].
///
/// Used by local data sources to serialize/deserialize accounts for Hive
/// storage. Enum values are stored as strings for forward compatibility.
library;

import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/site_type.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/check_in_config.dart';

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
    'accessToken': account.accessToken,
    'enabled': account.enabled,
    'notes': account.notes,
    'balance': account.balance,
    'username': account.username,
    'userId': account.userId,
    'exchangeRate': account.exchangeRate,
    'manualBalanceUsd': account.manualBalanceUsd,
    'excludeFromTotalBalance': account.excludeFromTotalBalance,
    'tagIds': List<String>.from(account.tagIds),
    'checkIn': _checkInToMap(account.checkIn),
    'redemptionUrl': account.redemptionUrl,
    'createdAt': account.createdAt.toIso8601String(),
    'updatedAt': account.updatedAt.toIso8601String(),
  };

  /// Deserializes a map back into an [Account].
  ///
  /// Missing fields (e.g. legacy records written before newer fields were
  /// introduced) fall back to defaults defined on the entity, so this mapper
  /// can safely read older Hive payloads.
  ///
  /// Legacy records may store a `siteType` string that no longer matches any
  /// known [SiteType]; those values are coerced to [SiteType.unknown] so the
  /// account still loads and the user can re-confirm the type in the editor.
  static Account fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['baseUrl'] as String,
      siteType: _readSiteType(map['siteType'] as String),
      authType: AuthType.values.firstWhere(
        (e) => e.name == (map['authType'] as String),
      ),
      accessToken: map['accessToken'] as String?,
      enabled: map['enabled'] as bool? ?? true,
      notes: map['notes'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      username: (map['username'] as String?) ?? '',
      userId: _readUserId(map['userId']),
      exchangeRate:
          (map['exchangeRate'] as num?)?.toDouble() ?? kDefaultUsdToCnyRate,
      manualBalanceUsd: (map['manualBalanceUsd'] as num?)?.toDouble(),
      excludeFromTotalBalance: map['excludeFromTotalBalance'] as bool? ?? false,
      tagIds: _readTagIds(map['tagIds']),
      checkIn: _checkInFromMap(map['checkIn']),
      redemptionUrl: map['redemptionUrl'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  /// Parses a persisted site-type value, falling back to [SiteType.unknown]
  /// when the string does not match any current enum entry. Prevents
  /// [ArgumentError] crashes when loading records written by older builds or
  /// by backends that have since been removed.
  static SiteType _readSiteType(String value) {
    try {
      return SiteType.fromValue(value);
    } on ArgumentError {
      return SiteType.unknown;
    }
  }

  /// Accepts `int`, `num`, or stringified numbers for forward compatibility
  /// with upstream sites that occasionally return user ids as strings.
  ///
  /// Returns `-1` (the [Account.userId] sentinel) when the field is missing
  /// or unparseable, so legacy records that predate the required user id
  /// still load without forcing a migration.
  static int _readUserId(Object? raw) {
    if (raw == null) return -1;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? -1;
    return -1;
  }

  static List<String> _readTagIds(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static Map<String, dynamic> _checkInToMap(CheckInConfig config) => {
    'autoCheckInEnabled': config.autoCheckInEnabled,
    'customCheckInUrl': config.customCheckInUrl,
  };

  static CheckInConfig _checkInFromMap(Object? raw) {
    if (raw is Map) {
      return CheckInConfig(
        autoCheckInEnabled: raw['autoCheckInEnabled'] as bool? ?? false,
        customCheckInUrl: raw['customCheckInUrl'] as String?,
      );
    }
    return CheckInConfig.disabled;
  }
}
