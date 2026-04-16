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
    final repo = ref.read(keysRepositoryProvider);
    final result = await repo.getByAccountId(accountId);
    return result.when(onSuccess: (keys) => keys, onFailure: (e) => throw e);
  }

  /// Creates a new API key and refreshes the list.
  Future<void> create(ApiKey apiKey, {String? keyValue}) async {
    state = const AsyncLoading();
    final repo = ref.read(keysRepositoryProvider);
    final result = await repo.create(apiKey, keyValue: keyValue);
    switch (result) {
      case Success():
        final updated = await repo.getByAccountId(arg);
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Updates an existing API key and refreshes the list.
  Future<void> saveKey(ApiKey apiKey, {String? keyValue}) async {
    state = const AsyncLoading();
    final repo = ref.read(keysRepositoryProvider);
    final result = await repo.update(apiKey, keyValue: keyValue);
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
    final repo = ref.read(keysRepositoryProvider);
    final result = await repo.delete(id);
    switch (result) {
      case Success():
        final updated = await repo.getByAccountId(arg);
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }
}
