/// Mapper between [Tag] domain entity and persistable [Map].
library;

import '../../domain/entities/tag.dart';

/// Converts [Tag] entities to and from JSON-compatible maps.
class TagMapper {
  const TagMapper._();

  /// Serializes a [Tag] into a persistable map.
  static Map<String, dynamic> toMap(Tag tag) => {
    'id': tag.id,
    'name': tag.name,
    'createdAt': tag.createdAt.toIso8601String(),
    'updatedAt': tag.updatedAt.toIso8601String(),
  };

  /// Deserializes a map back into a [Tag].
  static Tag fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
