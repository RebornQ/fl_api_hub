import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:fl_api_hub/features/check_in/data/datasources/check_in_local_datasource.dart';
import 'package:fl_api_hub/features/check_in/data/datasources/check_in_request_log_local_datasource.dart';
import 'package:fl_api_hub/features/check_in/data/models/check_in_mapper.dart';
import 'package:fl_api_hub/features/check_in/domain/entities/check_in_result.dart';

/// Helper to build a [CheckInResult] with minimal ceremony.
CheckInResult _mk({
  required String id,
  required String accountId,
  required String taskId,
  required DateTime executedAt,
  CheckInStatus status = CheckInStatus.success,
}) {
  return CheckInResult(
    id: id,
    taskId: taskId,
    accountId: accountId,
    status: status,
    executedAt: executedAt,
  );
}

void main() {
  late Directory tempDir;
  late Box taskBox;
  late Box resultBox;
  late Box requestLogBox;
  late CheckInLocalDataSource ds;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('check_in_ds_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final uid = const Uuid().v4();
    taskBox = await Hive.openBox('check_in_tasks_$uid');
    resultBox = await Hive.openBox('check_in_results_$uid');
    requestLogBox = await Hive.openBox('check_in_request_logs_$uid');
    ds = CheckInLocalDataSource(
      taskBox,
      resultBox,
      CheckInRequestLogLocalDataSource(requestLogBox),
    );
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await resultBox.deleteFromDisk();
    await requestLogBox.deleteFromDisk();
  });

  /// Writes a [CheckInResult] directly into the backing box without going
  /// through [CheckInLocalDataSource.saveResult]. Use this to stage pre-cap
  /// states (e.g. seeding 80 rows for one account) without the trim-on-write
  /// kicking in.
  Future<void> seedRaw(CheckInResult r) async {
    await resultBox.put(r.id, CheckInResultMapper.toMap(r));
  }

  group('saveResult trim-on-write', () {
    test(
      'caps a single account to 50 after 52 writes, evicting oldest first',
      () async {
        final base = DateTime(2026, 1, 1, 8);
        // Writes 52 records with strictly increasing executedAt. After each
        // write, pruneAccountResults should keep only the newest 50.
        for (var i = 0; i < 52; i++) {
          await ds.saveResult(
            _mk(
              id: 'r-$i',
              accountId: 'A',
              taskId: 't-A',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }

        expect(ds.countResultsByAccountId('A'), 50);

        // Oldest two (indices 0 and 1) should have been evicted; newest
        // (index 51) should still be present.
        final remaining = ds
            .getResultsByAccountId('A')
            .map((r) => r.id)
            .toSet();
        expect(remaining.contains('r-0'), isFalse);
        expect(remaining.contains('r-1'), isFalse);
        expect(remaining.contains('r-2'), isTrue);
        expect(remaining.contains('r-51'), isTrue);
      },
    );

    test('trim is scoped per accountId (A capped, B untouched)', () async {
      final base = DateTime(2026, 2, 1, 9);

      for (var i = 0; i < 52; i++) {
        await ds.saveResult(
          _mk(
            id: 'a-$i',
            accountId: 'A',
            taskId: 't-A',
            executedAt: base.add(Duration(minutes: i)),
          ),
        );
      }
      for (var i = 0; i < 30; i++) {
        await ds.saveResult(
          _mk(
            id: 'b-$i',
            accountId: 'B',
            taskId: 't-B',
            executedAt: base.add(Duration(minutes: i)),
          ),
        );
      }

      expect(ds.countResultsByAccountId('A'), 50);
      expect(ds.countResultsByAccountId('B'), 30);
    });
  });

  group('getLatestResultPerAccount', () {
    test(
      'returns the newest entry per account, overall sorted newest-first',
      () async {
        final base = DateTime(2026, 3, 1, 10);

        // Account A: two entries, newest is a2.
        await seedRaw(
          _mk(id: 'a1', accountId: 'A', taskId: 't-A', executedAt: base),
        );
        await seedRaw(
          _mk(
            id: 'a2',
            accountId: 'A',
            taskId: 't-A',
            executedAt: base.add(const Duration(minutes: 10)),
          ),
        );
        // Account B: three entries, newest is b3.
        await seedRaw(
          _mk(
            id: 'b1',
            accountId: 'B',
            taskId: 't-B',
            executedAt: base.add(const Duration(minutes: 5)),
          ),
        );
        await seedRaw(
          _mk(
            id: 'b2',
            accountId: 'B',
            taskId: 't-B',
            executedAt: base.add(const Duration(minutes: 15)),
          ),
        );
        await seedRaw(
          _mk(
            id: 'b3',
            accountId: 'B',
            taskId: 't-B',
            executedAt: base.add(const Duration(minutes: 30)),
          ),
        );
        // Account C: one entry.
        await seedRaw(
          _mk(
            id: 'c1',
            accountId: 'C',
            taskId: 't-C',
            executedAt: base.add(const Duration(minutes: 20)),
          ),
        );

        final latest = ds.getLatestResultPerAccount();

        expect(latest, hasLength(3));
        // Sorted newest-first: b3 (+30) > c1 (+20) > a2 (+10).
        expect(latest.map((r) => r.id).toList(), ['b3', 'c1', 'a2']);
      },
    );

    test('returns empty list when box has no results', () async {
      expect(ds.getLatestResultPerAccount(), isEmpty);
    });
  });

  group('getResultsByAccountIdPaged', () {
    test(
      'paginates newest-first over 45 records across multiple pages',
      () async {
        final base = DateTime(2026, 4, 1, 11);
        for (var i = 0; i < 45; i++) {
          await seedRaw(
            _mk(
              id: 'p-$i',
              accountId: 'A',
              taskId: 't-A',
              // Strictly increasing timestamps so newest-first ordering is
              // p-44, p-43, ..., p-0.
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }

        final firstPage = ds.getResultsByAccountIdPaged(
          'A',
          limit: 20,
          offset: 0,
        );
        expect(firstPage, hasLength(20));
        // Newest 20 are p-44..p-25.
        expect(firstPage.first.id, 'p-44');
        expect(firstPage.last.id, 'p-25');

        final secondPage = ds.getResultsByAccountIdPaged(
          'A',
          limit: 20,
          offset: 20,
        );
        expect(secondPage, hasLength(20));
        expect(secondPage.first.id, 'p-24');
        expect(secondPage.last.id, 'p-5');

        final thirdPage = ds.getResultsByAccountIdPaged(
          'A',
          limit: 20,
          offset: 40,
        );
        expect(thirdPage, hasLength(5));
        expect(thirdPage.first.id, 'p-4');
        expect(thirdPage.last.id, 'p-0');

        // Offset equal to total count → empty.
        expect(
          ds.getResultsByAccountIdPaged('A', limit: 20, offset: 45),
          isEmpty,
        );
        // Offset way past the end → empty (no crash).
        expect(
          ds.getResultsByAccountIdPaged('A', limit: 20, offset: 100),
          isEmpty,
        );
      },
    );
  });

  group('countResultsByAccountId', () {
    test(
      'matches getResultsByAccountId length for multiple accounts',
      () async {
        final base = DateTime(2026, 5, 1, 12);

        for (var i = 0; i < 7; i++) {
          await seedRaw(
            _mk(
              id: 'x-$i',
              accountId: 'X',
              taskId: 't-X',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }
        for (var i = 0; i < 3; i++) {
          await seedRaw(
            _mk(
              id: 'y-$i',
              accountId: 'Y',
              taskId: 't-Y',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }

        expect(
          ds.countResultsByAccountId('X'),
          ds.getResultsByAccountId('X').length,
        );
        expect(ds.countResultsByAccountId('X'), 7);
        expect(
          ds.countResultsByAccountId('Y'),
          ds.getResultsByAccountId('Y').length,
        );
        expect(ds.countResultsByAccountId('Y'), 3);
        expect(ds.countResultsByAccountId('Z'), 0);
      },
    );
  });

  group('deleteAllResultsByAccountId', () {
    test('removes every record for the account and preserves others', () async {
      final base = DateTime(2026, 6, 1, 13);
      for (var i = 0; i < 10; i++) {
        await seedRaw(
          _mk(
            id: 'a-$i',
            accountId: 'A',
            taskId: 't-A',
            executedAt: base.add(Duration(minutes: i)),
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        await seedRaw(
          _mk(
            id: 'b-$i',
            accountId: 'B',
            taskId: 't-B',
            executedAt: base.add(Duration(minutes: i)),
          ),
        );
      }

      final deleted = await ds.deleteAllResultsByAccountId('A');
      expect(deleted, 10);
      expect(ds.countResultsByAccountId('A'), 0);
      expect(ds.countResultsByAccountId('B'), 5);
    });
  });

  group('pruneAccountResults', () {
    test(
      'keeps the newest 50 entries and returns the number deleted',
      () async {
        final base = DateTime(2026, 7, 1, 14);

        // Seed 70 records bypassing saveResult so prune isn't auto-invoked.
        for (var i = 0; i < 70; i++) {
          await seedRaw(
            _mk(
              id: 'p-$i',
              accountId: 'A',
              taskId: 't-A',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }

        final deleted = await ds.pruneAccountResults('A');
        expect(deleted, 20);
        expect(ds.countResultsByAccountId('A'), 50);

        // The retained 50 should be indices 20..69 (newest).
        final remainingIds = ds
            .getResultsByAccountId('A')
            .map((r) => r.id)
            .toSet();
        for (var i = 0; i < 20; i++) {
          expect(
            remainingIds.contains('p-$i'),
            isFalse,
            reason: 'p-$i should have been pruned',
          );
        }
        for (var i = 20; i < 70; i++) {
          expect(
            remainingIds.contains('p-$i'),
            isTrue,
            reason: 'p-$i should have been retained',
          );
        }
      },
    );

    test('is a no-op when account is already under the cap', () async {
      final base = DateTime(2026, 8, 1, 15);
      for (var i = 0; i < 30; i++) {
        await seedRaw(
          _mk(
            id: 'u-$i',
            accountId: 'A',
            taskId: 't-A',
            executedAt: base.add(Duration(minutes: i)),
          ),
        );
      }

      final deleted = await ds.pruneAccountResults('A');
      expect(deleted, 0);
      expect(ds.countResultsByAccountId('A'), 30);
    });
  });

  group('migrateResultsToCap', () {
    test(
      'prunes every over-cap account, leaves under-cap accounts alone',
      () async {
        final base = DateTime(2026, 9, 1, 16);

        // A = 30 (under cap), B = 80 (over cap by 30), C = 50 (at cap).
        for (var i = 0; i < 30; i++) {
          await seedRaw(
            _mk(
              id: 'a-$i',
              accountId: 'A',
              taskId: 't-A',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }
        for (var i = 0; i < 80; i++) {
          await seedRaw(
            _mk(
              id: 'b-$i',
              accountId: 'B',
              taskId: 't-B',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }
        for (var i = 0; i < 50; i++) {
          await seedRaw(
            _mk(
              id: 'c-$i',
              accountId: 'C',
              taskId: 't-C',
              executedAt: base.add(Duration(minutes: i)),
            ),
          );
        }

        final totalPruned = await ds.migrateResultsToCap();
        expect(totalPruned, 30);

        expect(ds.countResultsByAccountId('A'), 30);
        expect(ds.countResultsByAccountId('B'), 50);
        expect(ds.countResultsByAccountId('C'), 50);

        // Every account now ≤ 50.
        for (final accountId in const ['A', 'B', 'C']) {
          expect(
            ds.countResultsByAccountId(accountId),
            lessThanOrEqualTo(kCheckInResultsCapPerAccount),
          );
        }
      },
    );
  });
}
