/// Tag entity representing a cross-feature label.
///
/// Tags are global first-class entities (not a property of a specific
/// account) so they can be shared and renamed without having to migrate
/// every account that references them. Accounts reference tags by [id].
library;

/// A reusable label attached to one or more accounts.
class Tag {
  /// Unique identifier (UUID v4).
  final String id;

  /// Display name as entered by the user. Preserves original case.
  final String name;

  /// Timestamp when this tag was first created.
  final DateTime createdAt;

  /// Timestamp when this tag was last modified (e.g. rename).
  final DateTime updatedAt;

  const Tag({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns a copy of this tag with the given fields replaced.
  Tag copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Case / whitespace-insensitive key used for deduplication.
  String get normalizedKey => name.trim().toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Tag && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tag(id: $id, name: $name)';
}
