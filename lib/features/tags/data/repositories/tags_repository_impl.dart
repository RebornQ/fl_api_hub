/// Concrete implementation of [TagsRepository] backed by local storage.
///
/// The repository enforces business invariants on top of
/// [TagsLocalDataSource]:
/// - `upsertByName` matches existing tags by normalized (trim + lowercase)
///   name while preserving the caller's casing when creating.
/// - `rename` refuses to collide with another existing tag's normalized
///   name.
/// - `delete` cascades to [AccountsRepository.removeTagFromAllAccounts]
///   so that accounts never carry orphan tag references.
library;

import 'package:uuid/uuid.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../../accounts/domain/repositories/accounts_repository.dart';
import '../../domain/entities/tag.dart';
import '../../domain/repositories/tags_repository.dart';
import '../datasources/tags_local_datasource.dart';

/// Local-only implementation of [TagsRepository].
class TagsRepositoryImpl implements TagsRepository {
  final TagsLocalDataSource _local;
  final AccountsRepository _accounts;
  final Uuid _uuid;

  TagsRepositoryImpl(this._local, this._accounts, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  @override
  Future<Result<List<Tag>>> getAll() async {
    try {
      return Success(_local.getAll());
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load tags: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Tag>> getById(String id) async {
    try {
      final tag = _local.getById(id);
      if (tag == null) {
        return const Failure(StorageException(message: 'Tag not found'));
      }
      return Success(tag);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to load tag: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Tag>> upsertByName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Failure(
        ValidationException(message: 'Tag name cannot be empty'),
      );
    }
    final normalized = trimmed.toLowerCase();
    try {
      final existing = _findByNormalized(normalized);
      if (existing != null) {
        return Success(existing);
      }
      final now = DateTime.now();
      final tag = Tag(
        id: _uuid.v4(),
        name: trimmed,
        createdAt: now,
        updatedAt: now,
      );
      await _local.save(tag);
      return Success(tag);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to upsert tag: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<Tag>> rename(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const Failure(
        ValidationException(message: 'Tag name cannot be empty'),
      );
    }
    final normalized = trimmed.toLowerCase();
    try {
      final current = _local.getById(id);
      if (current == null) {
        return const Failure(StorageException(message: 'Tag not found'));
      }
      // Guard against collision with a *different* existing tag.
      final collision = _findByNormalized(normalized);
      if (collision != null && collision.id != id) {
        return Failure(
          ValidationException(
            message: 'Another tag already uses the name "$trimmed"',
          ),
        );
      }
      final renamed = current.copyWith(
        name: trimmed,
        updatedAt: DateTime.now(),
      );
      await _local.save(renamed);
      return Success(renamed);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to rename tag: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final exists = _local.getById(id);
      if (exists == null) {
        return const Failure(StorageException(message: 'Tag not found'));
      }
      // Cascade first so we never leave account records pointing at a
      // tag id that has already disappeared.
      final cascade = await _accounts.removeTagFromAllAccounts(id);
      if (cascade is Failure<int>) {
        return Failure<void>(cascade.exception);
      }
      await _local.delete(id);
      return const Success(null);
    } catch (e, st) {
      return Failure(
        StorageException(
          message: 'Failed to delete tag: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    }
  }

  Tag? _findByNormalized(String normalized) {
    for (final tag in _local.getAll()) {
      if (tag.normalizedKey == normalized) return tag;
    }
    return null;
  }
}
