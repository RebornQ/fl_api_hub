/// Abstract interface and default implementation for encrypted key-value storage.
///
/// Sensitive data (API tokens, credentials) must go through [SecureStore]
/// so that they are stored in the platform's encrypted keystore
/// (iOS Keychain / Android Keystore).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interface for secure, encrypted key-value storage.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
  Future<bool> containsKey(String key);
}

/// [SecureStore] implementation backed by flutter_secure_storage.
class SecureStoreImpl implements SecureStore {
  final FlutterSecureStorage _storage;

  SecureStoreImpl()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}

/// Riverpod provider for the application-wide [SecureStore].
final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStoreImpl();
});
