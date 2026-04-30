/// Local data source for [Account] entities using Hive.
///
/// Account data (including access token) is stored as a single map in the
/// Hive `accounts` box. See [AccountMapper] for serialization details.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../domain/entities/account.dart';
import '../models/account_mapper.dart';

/// Box name for account entity storage.
const _boxName = 'accounts';

/// Local CRUD operations for [Account] entities.
class AccountsLocalDataSource {
  final Box _box;

  AccountsLocalDataSource(this._box);

  /// Returns all stored accounts.
  List<Account> getAll() {
    return _box.values
        .map(
          (dynamic raw) =>
              AccountMapper.fromMap(Map<String, dynamic>.from(raw)),
        )
        .toList();
  }

  /// Returns a single account by [id], or `null` if not found.
  Account? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return AccountMapper.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Persists an [account] to the local box.
  Future<void> save(Account account) async {
    await _box.put(account.id, AccountMapper.toMap(account));
  }

  /// Deletes an account by [id].
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Returns the number of stored accounts.
  int get count => _box.length;
}

/// Riverpod provider for [AccountsLocalDataSource].
///
/// Requires [initHive] to have been called.
final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>((
  ref,
) {
  return AccountsLocalDataSource(Hive.box(_boxName));
});
