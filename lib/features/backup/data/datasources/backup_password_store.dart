/// Password persistence for backup encryption using the `app_data` Hive box.
///
/// Stores two keys in the `app_data` box:
/// - `backup_password`: the encryption password (plain text).
/// - `backup_encrypted`: whether encryption is enabled.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages backup password persistence in the `app_data` Hive box.
class BackupPasswordStore {
  static const _keyPassword = 'backup_password';
  static const _keyEncrypted = 'backup_encrypted';

  final Box _box;

  BackupPasswordStore(this._box);

  /// Returns the stored password, or `null` if none is set.
  String? get password => _box.get(_keyPassword) as String?;

  /// Returns whether encryption is enabled (defaults to `true`).
  bool get isEncrypted => _box.get(_keyEncrypted) as bool? ?? false;

  /// Saves [password] and enables encryption.
  Future<void> setPassword(String password) async {
    await Future.wait([
      _box.put(_keyPassword, password),
      _box.put(_keyEncrypted, true),
    ]);
  }

  /// Clears the password and disables encryption.
  Future<void> clearPassword() async {
    await Future.wait([
      _box.delete(_keyPassword),
      _box.put(_keyEncrypted, false),
    ]);
  }

  /// Enables/disables encryption without changing the password.
  Future<void> setEncrypted(bool enabled) async {
    await _box.put(_keyEncrypted, enabled);
    if (!enabled) {
      await _box.delete(_keyPassword);
    }
  }
}

/// Riverpod provider for [BackupPasswordStore].
final backupPasswordStoreProvider = Provider<BackupPasswordStore>((ref) {
  return BackupPasswordStore(Hive.box('app_data'));
});
