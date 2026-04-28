/// API key entity representing a token/key associated with an account.
///
/// An [ApiKey] holds metadata and the secret value of a single API token,
/// persisted as a whole entity on local storage.
library;

/// An API key / token associated with an [Account].
class ApiKey {
  /// Unique identifier (UUID v4).
  final String id;

  /// Foreign key to the owning [Account].
  final String accountId;

  /// Display name for this key.
  final String name;

  /// Actual secret key value used in API calls. `null` if not set.
  ///
  /// Stored in plaintext as part of the entity on local persistence.
  final String? keyValue;

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

  /// Group name this key belongs to (optional).
  final String? group;

  const ApiKey({
    required this.id,
    required this.accountId,
    required this.name,
    this.keyValue,
    this.quota,
    this.usedQuota = 0,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.group,
  });

  /// Creates a copy of this key with the given fields replaced.
  ApiKey copyWith({
    String? id,
    String? accountId,
    String? name,
    String? keyValue,
    int? quota,
    int? usedQuota,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? group,
  }) {
    return ApiKey(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      keyValue: keyValue ?? this.keyValue,
      quota: quota ?? this.quota,
      usedQuota: usedQuota ?? this.usedQuota,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      group: group ?? this.group,
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
