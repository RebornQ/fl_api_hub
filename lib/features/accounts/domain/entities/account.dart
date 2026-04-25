/// Account entity representing a connected API site.
///
/// An [Account] holds the connection details for a single API endpoint,
/// including the access token used for authenticated calls.
library;

import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/site_type.dart';
import 'check_in_config.dart';

/// A connected API site account.
class Account {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display name chosen by the user.
  final String name;

  /// Base URL of the API endpoint (e.g. "https://api.example.com").
  final String baseUrl;

  /// Backend type of the site (determines API adapter behavior).
  final SiteType siteType;

  /// Authentication method for this account.
  final AuthType authType;

  /// Access token used for authenticated API calls. `null` if not set.
  ///
  /// Stored in plaintext as part of the entity on local persistence.
  final String? accessToken;

  /// Whether this account is active and available for operations.
  final bool enabled;

  /// Optional user notes or remarks.
  final String? notes;

  /// Cached account balance (USD), updated after API sync.
  /// `null` if never synced.
  final double? balance;

  /// Account username as reported by the upstream site.
  ///
  /// Empty string `''` is the sentinel for "not yet filled" — the editor
  /// treats this as an unfilled field and requires the user to enter a
  /// real value before saving. Legacy records that predate the required
  /// username field are rehydrated with this sentinel by [AccountMapper].
  final String username;

  /// Account user id as reported by the upstream site.
  ///
  /// `-1` is the sentinel for "not yet filled" — the editor treats any
  /// non-positive value as unfilled and requires the user to enter a
  /// positive id before saving. Legacy records that predate the required
  /// user id are rehydrated with this sentinel by [AccountMapper].
  final int userId;

  /// Exchange rate used to convert USD balances into CNY for display.
  /// Defaults to [kDefaultUsdToCnyRate] when the site does not provide one.
  final double exchangeRate;

  /// Optional user-specified balance override (USD).
  ///
  /// When non-null, UI should display this value instead of the auto-fetched
  /// [balance]. Useful for sites that do not expose balance APIs.
  final double? manualBalanceUsd;

  /// Whether this account is excluded from aggregate "total balance" stats.
  ///
  /// Does **not** disable refresh / check-in behavior — this flag only
  /// affects dashboard aggregation.
  final bool excludeFromTotalBalance;

  /// IDs of tags associated with this account (references into the global
  /// tag store). Always non-null; empty list means "no tags".
  final List<String> tagIds;

  /// Per-account check-in configuration (static part).
  ///
  /// See [CheckInConfig] for the scheduling-vs-config split.
  final CheckInConfig checkIn;

  /// Optional redemption / top-up page URL.
  ///
  /// Rendered alongside the check-in section in the edit UI but conceptually
  /// independent of the check-in flow (it points to the site's quota
  /// purchase / redemption page).
  final String? redemptionUrl;

  /// Timestamp when this account was created locally.
  final DateTime createdAt;

  /// Timestamp when this account was last modified.
  final DateTime updatedAt;

  /// User-defined sort position within the enabled or disabled partition.
  /// Lower values appear first. Defaults to `0` for legacy records.
  final int sortOrder;

  const Account({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.siteType,
    required this.authType,
    this.accessToken,
    this.enabled = true,
    this.notes,
    this.balance,
    this.username = '',
    this.userId = -1,
    this.exchangeRate = kDefaultUsdToCnyRate,
    this.manualBalanceUsd,
    this.excludeFromTotalBalance = false,
    this.tagIds = const [],
    this.checkIn = CheckInConfig.disabled,
    this.redemptionUrl,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  /// Creates a copy of this account with the given fields replaced.
  Account copyWith({
    String? id,
    String? name,
    String? baseUrl,
    SiteType? siteType,
    AuthType? authType,
    String? accessToken,
    bool? enabled,
    String? notes,
    double? balance,
    String? username,
    int? userId,
    double? exchangeRate,
    double? manualBalanceUsd,
    bool? excludeFromTotalBalance,
    List<String>? tagIds,
    CheckInConfig? checkIn,
    String? redemptionUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      siteType: siteType ?? this.siteType,
      authType: authType ?? this.authType,
      accessToken: accessToken ?? this.accessToken,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      manualBalanceUsd: manualBalanceUsd ?? this.manualBalanceUsd,
      excludeFromTotalBalance:
          excludeFromTotalBalance ?? this.excludeFromTotalBalance,
      tagIds: tagIds ?? this.tagIds,
      checkIn: checkIn ?? this.checkIn,
      redemptionUrl: redemptionUrl ?? this.redemptionUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Field-by-field deep equality helper.
  ///
  /// Distinct from [operator ==] which uses id-based identity semantics
  /// (entities stay "equal" across field edits). Use [deepEquals] when you
  /// need to detect any field change, e.g. for `isDirty` computations.
  bool deepEquals(Account other) {
    if (identical(this, other)) return true;
    if (id != other.id) return false;
    if (name != other.name) return false;
    if (baseUrl != other.baseUrl) return false;
    if (siteType != other.siteType) return false;
    if (authType != other.authType) return false;
    if (accessToken != other.accessToken) return false;
    if (enabled != other.enabled) return false;
    if (notes != other.notes) return false;
    if (balance != other.balance) return false;
    if (username != other.username) return false;
    if (userId != other.userId) return false;
    if (exchangeRate != other.exchangeRate) return false;
    if (manualBalanceUsd != other.manualBalanceUsd) return false;
    if (excludeFromTotalBalance != other.excludeFromTotalBalance) return false;
    if (!_listEquals(tagIds, other.tagIds)) return false;
    if (checkIn != other.checkIn) return false;
    if (redemptionUrl != other.redemptionUrl) return false;
    if (createdAt != other.createdAt) return false;
    if (updatedAt != other.updatedAt) return false;
    if (sortOrder != other.sortOrder) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Account && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Account(id: $id, name: $name, siteType: $siteType)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
