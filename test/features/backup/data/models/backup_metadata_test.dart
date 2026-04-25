import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/backup_metadata.dart';

void main() {
  group('BackupMetadata', () {
    test('toMap and fromMap round-trip', () {
      final timestamp = DateTime.parse('2026-04-25T14:30:00.000Z');
      final metadata = BackupMetadata(
        version: 1,
        encrypted: true,
        timestamp: timestamp,
        appVersion: '1.0.0',
        checksum: 'abc123',
      );
      final map = metadata.toMap();
      final restored = BackupMetadata.fromMap(map);

      expect(restored.version, 1);
      expect(restored.encrypted, true);
      expect(restored.appVersion, '1.0.0');
      expect(restored.checksum, 'abc123');
    });

    test('fromMap handles missing fields with defaults', () {
      final restored = BackupMetadata.fromMap({});
      expect(restored.version, 1);
      expect(restored.encrypted, false);
      expect(restored.appVersion, '0.0.0');
      expect(restored.checksum, '');
    });

    test('encrypted flag is preserved', () {
      final timestamp = DateTime.parse('2026-04-25T14:30:00.000Z');

      final plain = BackupMetadata(
        version: 1,
        encrypted: false,
        timestamp: timestamp,
        appVersion: '1.0.0',
        checksum: '',
      );
      expect(BackupMetadata.fromMap(plain.toMap()).encrypted, false);

      final enc = BackupMetadata(
        version: 1,
        encrypted: true,
        timestamp: timestamp,
        appVersion: '1.0.0',
        checksum: '',
      );
      expect(BackupMetadata.fromMap(enc.toMap()).encrypted, true);
    });
  });
}
