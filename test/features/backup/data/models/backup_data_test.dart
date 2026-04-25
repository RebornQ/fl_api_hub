import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/backup_data.dart';

void main() {
  group('BackupData', () {
    final data = BackupData(
      accounts: [
        {'id': 'acc1', 'name': 'Test Account'},
      ],
      keys: [
        {'id': 'key1', 'accountId': 'acc1'},
      ],
      tags: [
        {'id': 'tag1', 'name': 'production'},
      ],
      checkInTasks: [],
      checkInResults: [],
      schedulerConfig: {'enabled': true},
      appData: {'theme_mode': 'dark'},
    );

    test('toMap and fromMap round-trip', () {
      final map = data.toMap();
      final restored = BackupData.fromMap(map);

      expect(restored.accounts.length, 1);
      expect(restored.accounts.first['id'], 'acc1');
      expect(restored.keys.length, 1);
      expect(restored.tags.first['name'], 'production');
      expect(restored.schedulerConfig['enabled'], true);
      expect(restored.appData['theme_mode'], 'dark');
    });

    test('fromMap handles empty/null fields', () {
      final restored = BackupData.fromMap({});
      expect(restored.accounts, isEmpty);
      expect(restored.keys, isEmpty);
      expect(restored.tags, isEmpty);
      expect(restored.schedulerConfig, isEmpty);
      expect(restored.appData, isEmpty);
    });

    test('preserves all list fields independently', () {
      final map = data.toMap();
      final restored = BackupData.fromMap(map);

      expect(restored.checkInTasks, isEmpty);
      expect(restored.checkInResults, isEmpty);
      expect(restored.accounts, isNotEmpty);
      expect(restored.keys, isNotEmpty);
    });
  });
}
