/// State management for the tag list.
///
/// [TagsNotifier] loads all tags on first watch and exposes mutation methods
/// (`upsertByName`, `rename`, `delete`). All mutations are serialized through
/// an internal single-slot queue so two rapid `upsertByName` calls with the
/// same normalized name reliably return the same id (no duplicate rows).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/tag.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import 'tags_providers.dart';

/// Manages the async state of the tag list.
class TagsNotifier extends AsyncNotifier<List<Tag>> {
  /// Chain of pending write operations. Each write awaits the previous one
  /// to complete (success *or* failure) before executing its own work.
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<List<Tag>> build() async {
    // Tag list is small and frequently consulted; keep it resident so we
    // don't re-read Hive every time the edit dialog closes.
    ref.keepAlive();
    final repo = ref.read(tagsRepositoryProvider);
    final result = await repo.getAll();
    return result.when(onSuccess: (tags) => tags, onFailure: (e) => throw e);
  }

  /// Creates a tag (or returns the existing one matching by normalized
  /// name). Serialized so concurrent calls don't produce duplicates.
  Future<Tag> upsertByName(String name) async {
    return _enqueue(() async {
      final repo = ref.read(tagsRepositoryProvider);
      final result = await repo.upsertByName(name);
      return switch (result) {
        Success(:final data) => () {
          _upsertInState(data);
          return data;
        }(),
        Failure(:final exception) => throw exception,
      };
    });
  }

  /// Renames a tag by id.
  Future<Tag> rename(String id, String newName) async {
    return _enqueue(() async {
      final repo = ref.read(tagsRepositoryProvider);
      final result = await repo.rename(id, newName);
      return switch (result) {
        Success(:final data) => () {
          _upsertInState(data);
          return data;
        }(),
        Failure(:final exception) => throw exception,
      };
    });
  }

  /// Deletes a tag by id, triggering a cascade cleanup on accounts and
  /// invalidating [accountsProvider] so any UI watching the account list
  /// re-reads the freshly-updated records.
  Future<void> delete(String id) async {
    await _enqueue(() async {
      final repo = ref.read(tagsRepositoryProvider);
      final result = await repo.delete(id);
      if (result is Failure<void>) throw result.exception;
      _removeFromState(id);
      // Account records may have had this tagId removed as part of the
      // cascade — force consumers to re-read the latest list.
      ref.invalidate(accountsProvider);
    });
  }

  /// Helpers -----------------------------------------------------------

  /// Runs [action] after any previously queued write has settled.
  Future<T> _enqueue<T>(Future<T> Function() action) async {
    final previous = _writeQueue;
    final completer = Completer<void>();
    _writeQueue = completer.future;
    try {
      // Wait for the preceding write but never propagate its failure
      // into this one.
      await previous.catchError((Object _, StackTrace _) {});
      return await action();
    } finally {
      completer.complete();
    }
  }

  void _upsertInState(Tag tag) {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == tag.id);
    if (idx == -1) {
      state = AsyncData([...current, tag]);
    } else {
      final next = List<Tag>.from(current);
      next[idx] = tag;
      state = AsyncData(next);
    }
  }

  void _removeFromState(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((t) => t.id != id).toList(growable: false));
  }
}
