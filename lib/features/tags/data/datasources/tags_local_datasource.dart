/// Local data source for [Tag] entities using Hive.
///
/// Tags are stored in the Hive `tags` box keyed by their UUID id.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/tag.dart';
import '../models/tag_mapper.dart';

/// Box name for tag entity storage.
const _boxName = 'tags';

/// Local CRUD operations for [Tag] entities.
class TagsLocalDataSource {
  final Box _box;

  TagsLocalDataSource(this._box);

  /// Returns every stored tag (unordered).
  List<Tag> getAll() {
    return _box.values
        .map((dynamic raw) => TagMapper.fromMap(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  /// Returns a single tag by [id], or `null` if not found.
  Tag? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return TagMapper.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Persists a [tag] to the local box.
  Future<void> save(Tag tag) async {
    await _box.put(tag.id, TagMapper.toMap(tag));
  }

  /// Deletes a tag by [id].
  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}

/// Riverpod provider for [TagsLocalDataSource]. Requires [initHive] to have
/// opened the `tags` box first.
final tagsLocalDataSourceProvider = Provider<TagsLocalDataSource>((ref) {
  return TagsLocalDataSource(Hive.box(_boxName));
});
