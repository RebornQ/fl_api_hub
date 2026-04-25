/// Encryption, decryption, and checksum utilities for backup files.
///
/// Encrypted format (binary): `[32-byte salt][12-byte nonce][AES-256-GCM ciphertext + tag]`
/// Unencrypted format: UTF-8 JSON text.
///
/// Detection: first byte `{` (0x7B) → unencrypted JSON, else → encrypted binary.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Codec for encrypting/decrypting backup payloads.
class BackupCodec {
  const BackupCodec._();

  static final _random = Random.secure();

  // -- Encryption -----------------------------------------------------------

  /// Encrypts [json] with AES-256-GCM using a key derived from [password].
  ///
  /// Returns `[32-byte salt][12-byte nonce][ciphertext + GCM tag]`.
  static Uint8List encrypt(String json, String password) {
    final salt = _randomBytes(32);
    final nonce = _randomBytes(12);
    final key = _deriveKey(password, salt);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(json, iv: enc.IV(nonce));

    final result = BytesBuilder();
    result.add(salt);
    result.add(nonce);
    result.add(encrypted.bytes);
    return result.toBytes();
  }

  /// Decrypts [encryptedBytes] back to a JSON string.
  ///
  /// Throws [FormatException] if the password is wrong or data is corrupted.
  static String decrypt(Uint8List encryptedBytes, String password) {
    if (encryptedBytes.length < 45) {
      throw const FormatException('Backup file too short or corrupted');
    }

    final salt = Uint8List.sublistView(encryptedBytes, 0, 32);
    final nonce = Uint8List.sublistView(encryptedBytes, 32, 44);
    final ciphertext = Uint8List.sublistView(encryptedBytes, 44);

    final key = _deriveKey(password, salt);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    try {
      return encrypter.decrypt(enc.Encrypted(ciphertext), iv: enc.IV(nonce));
    } catch (e) {
      throw const FormatException(
        'Decryption failed — wrong password or corrupted data',
      );
    }
  }

  // -- Checksum -------------------------------------------------------------

  /// Computes SHA-256 hex digest of [data].
  static String computeChecksum(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  // -- File type detection --------------------------------------------------

  /// Returns `true` if [bytes] starts with `{` (unencrypted JSON).
  static bool isJson(Uint8List bytes) {
    return bytes.isNotEmpty && bytes[0] == 0x7B; // '{'
  }

  // -- Key derivation -------------------------------------------------------

  /// Derives a 256-bit key from [password] and [salt] using PBKDF2.
  static enc.Key _deriveKey(String password, Uint8List salt) {
    return enc.Key.fromUtf8(
      password,
    ).stretch(32, iterationCount: 100000, salt: salt);
  }

  static Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List.generate(length, (_) => _random.nextInt(256)),
    );
  }
}
