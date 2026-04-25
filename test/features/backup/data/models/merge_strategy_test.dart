import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/backup_data.dart';
import 'package:fl_api_hub/features/backup/data/models/merge_strategy.dart';

void main() {
  group('resolveMerge', () {
    late BackupData local;

    setUp(() {
      local = BackupData(
        accounts: [
          {
            'id': 'acc1',
            'name': 'Local Account',
            'updatedAt': '2026-01-01T00:00:00.000Z',
            'tagIds': ['tag1'],
          },
        ],
        keys: [
          {'id': 'key1', 'accountId': 'acc1', 'updatedAt': '2026-01-01'},
        ],
        tags: [
          {'id': 'tag1', 'name': 'production', 'updatedAt': '2026-01-01'},
        ],
        checkInTasks: [
          {'id': 'task1', 'accountId': 'acc1'},
        ],
        checkInResults: [
          {'id': 'result1', 'taskId': 'task1', 'accountId': 'acc1'},
        ],
        schedulerConfig: {'enabled': false},
        appData: {'theme_mode': 'light'},
      );
    });

    test('inserts new entities when IDs do not exist locally', () {
      final incoming = BackupData(
        accounts: [
          {
            'id': 'acc2',
            'name': 'New Account',
            'updatedAt': '2026-02-01T00:00:00.000Z',
            'tagIds': [],
          },
        ],
        keys: [
          {'id': 'key2', 'accountId': 'acc2'},
        ],
        tags: [
          {'id': 'tag2', 'name': 'staging', 'updatedAt': '2026-02-01'},
        ],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {'some_key': 'some_value'},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.accountsInserted, 1);
      expect(result.tagsInserted, 1);
      expect(result.keysInserted, 1);
      expect(resolved.accounts.length, 2);
      expect(resolved.tags.length, 2);
      expect(resolved.keys.length, 2);
    });

    test('keeps newer version when IDs match', () {
      final incoming = BackupData(
        accounts: [
          {
            'id': 'acc1',
            'name': 'Updated Account',
            'updatedAt': '2026-06-01T00:00:00.000Z',
            'tagIds': [],
          },
        ],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.accountsUpdated, 1);
      expect(resolved.accounts.first['name'], 'Updated Account');
    });

    test('skips orphan keys when parent account does not exist', () {
      final incoming = BackupData(
        accounts: [],
        keys: [
          {'id': 'key_orphan', 'accountId': 'nonexistent_account'},
        ],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.keysSkipped, 1);
      expect(resolved.keys.length, 1); // only local key1
    });

    test('skips orphan check-in results', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [
          {
            'id': 'result_orphan',
            'taskId': 'nonexistent',
            'accountId': 'nonexistent',
          },
        ],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.resultsSkipped, 1);
      expect(resolved.checkInResults.length, 1); // only local result1
    });

    test('renames tags on synonym conflict', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [
          {
            'id': 'tag_different',
            'name': 'production',
            'updatedAt': '2026-02-01',
          },
        ],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.tagsConflicted, 1);
      expect(resolved.tags.length, 2);
      expect(resolved.tags.any((t) => t['name'] == 'production (备份)'), isTrue);
    });

    test('merges account tagIds as union', () {
      final incoming = BackupData(
        accounts: [
          {
            'id': 'acc1',
            'name': 'Updated',
            'updatedAt': '2026-06-01T00:00:00.000Z',
            'tagIds': ['tag2'],
          },
        ],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: _) = resolveMerge(local, incoming);

      final merged = resolved.accounts.first;
      final tagIds = List<String>.from(merged['tagIds'] as List);
      expect(tagIds, containsAll(['tag1', 'tag2']));
    });

    test('scheduler config: backup wins if enabled=true', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {'enabled': true, 'timeWindowStart': '09:00'},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.schedulerUpdated, isTrue);
      expect(resolved.schedulerConfig['enabled'], true);
    });

    test('scheduler config: local wins if backup has enabled=false', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {'enabled': false},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      expect(result.schedulerUpdated, isFalse);
      // Local config preserved.
      expect(resolved.schedulerConfig['enabled'], false);
    });

    test('app data: backup values override local', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [],
        schedulerConfig: {},
        appData: {'theme_mode': 'dark', 'new_key': 'new_value'},
      );

      final (resolved: resolved, result: _) = resolveMerge(local, incoming);

      expect(resolved.appData['theme_mode'], 'dark');
      expect(resolved.appData['new_key'], 'new_value');
    });

    test('existing check-in results are kept (immutable)', () {
      final incoming = BackupData(
        accounts: [],
        keys: [],
        tags: [],
        checkInTasks: [],
        checkInResults: [
          {
            'id': 'result1',
            'taskId': 'task1',
            'accountId': 'acc1',
            'message': 'already exists',
          },
        ],
        schedulerConfig: {},
        appData: {},
      );

      final (resolved: resolved, result: result) = resolveMerge(
        local,
        incoming,
      );

      // Result already exists locally — not re-inserted.
      expect(result.resultsInserted, 0);
      expect(resolved.checkInResults.length, 1);
    });
  });
}
