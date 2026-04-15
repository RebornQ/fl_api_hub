/// API key entity representing a token/key associated with an account.
///
/// An [ApiKey] holds metadata about a single API token. The actual secret
/// key value is stored separately via [SecureStore] (key: `api_key_value_{id}`)
/// and is NOT part of this entity.
library;

/// An API key / token associated with an [Account].
class ApiKey {
  /// Unique identifier (UUID v4).
  final String id;

  /// Foreign key to the owning [Account].
  final String accountId;

  /// Display name for this key.
  final String name;

  /// Quota limit for this key. `null` means unlimited.
  final int? quota;

  /// Amount of quota already consumed.
  final int usedQuota;

  /// Expiration timestamp. `null` means never expires.
  final DateTime? expiresAt;

  /// Timestamp when this key was created.
  final DateTime createdAt;

  /// Timestamp when this key was last modified.
  final DateTime updatedAt;

  const ApiKey({
    required this.id,
    required this.accountId,
    required this.name,
    this.quota,
    this.usedQuota = 0,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this key with the given fields replaced.
  ApiKey copyWith({
    String? id,
    String? accountId,
    String? name,
    int? quota,
    int? usedQuota,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApiKey(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      quota: quota ?? this.quota,
      usedQuota: usedQuota ?? this.usedQuota,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Remaining quota. `null` if quota is unlimited.
  int? get remainingQuota => quota != null ? quota! - usedQuota : null;

  /// Whether this key has expired.
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ApiKey && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ApiKey(id: $id, name: $name, accountId: $accountId)';
}
