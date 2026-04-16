/// State management for the account list.
///
/// [AccountsNotifier] loads all accounts on first watch and exposes mutation
/// methods (create, update, delete, toggleEnabled). Every mutation performs
/// a pessimistic update — the full list is re-read from the repository after
/// each successful write.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/entities/account.dart';
import 'accounts_providers.dart';

/// Manages the async state of the accounts list.
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.getAll();
    return result.when(
      onSuccess: (accounts) => accounts,
      onFailure: (e) => throw e,
    );
  }

  /// Creates a new account and refreshes the list.
  Future<void> create(Account account, {String? accessToken}) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.create(account, accessToken: accessToken);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Updates an existing account and refreshes the list.
  Future<void> saveAccount(Account account, {String? accessToken}) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(account, accessToken: accessToken);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Deletes an account by [id] and refreshes the list.
  Future<void> delete(String id) async {
    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.delete(id);
    switch (result) {
      case Success():
        final updated = await repo.getAll();
        state = AsyncData(updated.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }

  /// Toggles the enabled state of an account and refreshes the list.
  Future<void> toggleEnabled(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final account = current.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Account $id not found in state'),
    );
    final updated = account.copyWith(
      enabled: !account.enabled,
      updatedAt: DateTime.now(),
    );

    state = const AsyncLoading();
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.update(updated);
    switch (result) {
      case Success():
        final all = await repo.getAll();
        state = AsyncData(all.dataOrNull ?? []);
      case Failure(:final exception):
        state = AsyncError(exception, StackTrace.current);
    }
  }
}
