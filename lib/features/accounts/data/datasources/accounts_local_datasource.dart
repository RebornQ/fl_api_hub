/// Local data source for [Account] entities using Hive + SecureStore.
///
/// Account metadata is stored in a Hive box, while access tokens are kept
/// in encrypted storage via [SecureStore]. This separation prevents sensitive
/// credentials from appearing in unencrypted backups.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/account.dart';
import '../models/account_mapper.dart';

/// Box name for account entity storage.
const _boxName = 'accounts';

/// SecureStore key prefix for account access tokens.
const _tokenKeyPrefix = 'account_token_';

/// Local CRUD operations for [Account] entities.
class AccountsLocalDataSource {
  final Box _box;
  final SecureStore _secureStore;

  AccountsLocalDataSource(this._box, this._secureStore);

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
  ///
  /// If [accessToken] is provided, it is stored securely and separately.
  Future<void> save(Account account, {String? accessToken}) async {
    await _box.put(account.id, AccountMapper.toMap(account));
    if (accessToken != null) {
      await _secureStore.write('$_tokenKeyPrefix${account.id}', accessToken);
    }
  }

  /// Retrieves the stored access token for account [accountId].
  ///
  /// Returns `null` if no token has been stored.
  Future<String?> getAccessToken(String accountId) {
    return _secureStore.read('$_tokenKeyPrefix$accountId');
  }

  /// Deletes an account and its associated access token.
  Future<void> delete(String id) async {
    await _box.delete(id);
    await _secureStore.delete('$_tokenKeyPrefix$id');
  }

  /// Returns the number of stored accounts.
  int get count => _box.length;
}

/// Riverpod provider for [AccountsLocalDataSource].
///
/// Requires [initHive] to have been called and [secureStoreProvider]
/// to be available in the provider scope.
final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>((
  ref,
) {
  return AccountsLocalDataSource(
    Hive.box(_boxName),
    ref.watch(secureStoreProvider),
  );
});
