/// State management for the API key list.
///
/// [KeysNotifier] is a family notifier parameterized by [accountId]. It loads
/// all keys belonging to that account and exposes mutation methods (create,
/// update, delete). Every mutation performs a pessimistic update.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/api_key.dart';
import 'keys_providers.dart';

/// Manages the async state of the API key list for a single account.
class KeysNotifier extends FamilyAsyncNotifier<List<ApiKey>, String> {
  @override
  Future<List<ApiKey>> build(String accountId) async {
    final repo = ref.read(keysRepositoryProvider(accountId));
    final result = await repo.getByAccountId(accountId);
    return result.when(
      onSuccess: (keys) => keys,
      onFailure: (e) => throw e,
    );
  }

  /// Creates a new API key and refreshes the list.
  Future<void> create(ApiKey apiKey) async {
    state = const AsyncLoading();
    final repo = ref.read(keysRepositoryProvider(arg));
    final result = await repo.create(apiKey);
    switch (result) {
      case Success():
        final updated = await repo.getByAccountId(arg);
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Updates an existing API key and refreshes the list.
  Future<void> saveKey(ApiKey apiKey) async {
    state = const AsyncLoading();
    final repo = ref.read(keysRepositoryProvider(arg));
    final result = await repo.update(apiKey);
    switch (result) {
      case Success():
        final updated = await repo.getByAccountId(arg);
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Deletes an API key by [id] and refreshes the list.
  Future<void> delete(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(keysRepositoryProvider(arg));
    final result = await repo.delete(id);
    switch (result) {
      case Success():
        final updated = await repo.getByAccountId(arg);
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Resolves a masked key to the full value and patches the current list.
  ///
  /// Does NOT re-fetch from remote (which would return masked keys and
  /// overwrite the resolved value). Instead, updates only the resolved
  /// key in-place within the current state.
  Future<void> resolveKey(String keyId) async {
    final repo = ref.read(keysRepositoryProvider(arg));
    final result = await repo.resolveKey(keyId, arg);
    switch (result) {
      case Success(:final data):
        final current = state.valueOrNull ?? [];
        state = AsyncData([
          for (final k in current)
            if (k.id == keyId) data else k,
        ]);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }
}
