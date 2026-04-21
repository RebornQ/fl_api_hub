/// Repository contract for [Tag] operations.
///
/// Implementations provide CRUD + case-insensitive upsert semantics. All
/// methods return [Result] to enforce explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/tag.dart';

/// Abstract repository for tag CRUD operations.
abstract class TagsRepository {
  /// Returns every known tag.
  Future<Result<List<Tag>>> getAll();

  /// Returns a single tag by [id], or a [Failure] if it does not exist.
  Future<Result<Tag>> getById(String id);

  /// Creates a tag if no tag with the same normalized name exists yet,
  /// otherwise returns the existing one. Preserves the caller's original
  /// casing when creating.
  ///
  /// The raw [name] is trimmed before use. Empty / whitespace-only names
  /// are rejected with a [Failure].
  Future<Result<Tag>> upsertByName(String name);

  /// Renames the tag identified by [id]. Fails if no tag with the new
  /// normalized name already exists and belongs to a different id, so
  /// callers never accidentally create a duplicate via rename.
  Future<Result<Tag>> rename(String id, String newName);

  /// Deletes the tag identified by [id]. Implementations are expected to
  /// cascade the deletion to any account references.
  Future<Result<void>> delete(String id);
}
