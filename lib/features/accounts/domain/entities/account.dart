/// Account entity representing a connected API site.
///
/// An [Account] holds the connection details for a single API endpoint.
/// Sensitive data (access token) is stored separately via [SecureStore]
/// and is NOT part of this entity to prevent accidental leakage.
library;

import '../../../../core/network/site_type.dart';

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

  /// Whether this account is active and available for operations.
  final bool enabled;

  /// Optional user notes or remarks.
  final String? notes;

  /// Cached account balance, updated after API sync.
  /// `null` if never synced.
  final double? balance;

  /// Timestamp when this account was created locally.
  final DateTime createdAt;

  /// Timestamp when this account was last modified.
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.siteType,
    required this.authType,
    this.enabled = true,
    this.notes,
    this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this account with the given fields replaced.
  Account copyWith({
    String? id,
    String? name,
    String? baseUrl,
    SiteType? siteType,
    AuthType? authType,
    bool? enabled,
    String? notes,
    double? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      siteType: siteType ?? this.siteType,
      authType: authType ?? this.authType,
      enabled: enabled ?? this.enabled,
      notes: notes ?? this.notes,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Account && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Account(id: $id, name: $name, siteType: $siteType)';
}
