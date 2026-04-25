import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/backup_codec.dart';

void main() {
  group('BackupCodec', () {
    const testJson = '{"version":1,"data":{"accounts":[]}}';

    test('encrypt then decrypt round-trips', () {
      final encrypted = BackupCodec.encrypt(testJson, 'my_password');
      final decrypted = BackupCodec.decrypt(encrypted, 'my_password');
      expect(decrypted, testJson);
    });

    test('encrypted output is not JSON', () {
      final encrypted = BackupCodec.encrypt(testJson, 'pw');
      expect(BackupCodec.isJson(encrypted), isFalse);
    });

    test('wrong password throws FormatException', () {
      final encrypted = BackupCodec.encrypt(testJson, 'correct');
      expect(
        () => BackupCodec.decrypt(encrypted, 'wrong'),
        throwsFormatException,
      );
    });

    test('garbage input throws on decrypt', () {
      expect(
        () => BackupCodec.decrypt(Uint8List.fromList(List.filled(10, 0)), 'pw'),
        throwsFormatException,
      );
    });

    test('different passwords produce different ciphertext', () {
      final a = BackupCodec.encrypt(testJson, 'alpha');
      final b = BackupCodec.encrypt(testJson, 'beta');
      expect(a, isNot(equals(b)));
    });

    test('same password produces different ciphertext (random salt/nonce)', () {
      final a = BackupCodec.encrypt(testJson, 'same');
      final b = BackupCodec.encrypt(testJson, 'same');
      expect(a, isNot(equals(b)));
    });

    test('isJson returns true for JSON bytes', () {
      expect(BackupCodec.isJson(utf8.encode('{"key":"value"}')), isTrue);
    });

    test('isJson returns false for binary bytes', () {
      expect(BackupCodec.isJson(Uint8List.fromList([0x00, 0x01])), isFalse);
    });

    test('computeChecksum is deterministic', () {
      final a = BackupCodec.computeChecksum('hello');
      final b = BackupCodec.computeChecksum('hello');
      expect(a, b);
      expect(a, sha256.convert(utf8.encode('hello')).toString());
    });

    test('computeChecksum differs for different inputs', () {
      final a = BackupCodec.computeChecksum('hello');
      final b = BackupCodec.computeChecksum('world');
      expect(a, isNot(equals(b)));
    });
  });
}
