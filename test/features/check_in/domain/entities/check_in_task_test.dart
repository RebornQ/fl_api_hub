import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/check_in/domain/entities/check_in_task.dart';

void main() {
  group('CheckInTask', () {
    late CheckInTask testTask;

    setUp(() {
      testTask = CheckInTask(
        id: 'task-id-1',
        accountId: 'account-id-1',
        enabled: true,
        scheduleTime: '08:00',
        lastRunAt: DateTime(2026, 4, 15, 8, 0),
        nextRunAt: DateTime(2026, 4, 16, 8, 0),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 4, 15),
      );
    });

    test('constructs with required fields', () {
      expect(testTask.id, 'task-id-1');
      expect(testTask.accountId, 'account-id-1');
      expect(testTask.enabled, true);
      expect(testTask.scheduleTime, '08:00');
    });

    test('constructs with default values', () {
      final task = CheckInTask(
        id: 'id',
        accountId: 'acc-id',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(task.enabled, true);
      expect(task.scheduleTime, '08:00');
      expect(task.lastRunAt, isNull);
      expect(task.nextRunAt, isNull);
    });

    test('copyWith replaces specified fields', () {
      final updated = testTask.copyWith(
        enabled: false,
        scheduleTime: '10:00',
        lastRunAt: DateTime(2026, 4, 16, 10, 0),
      );

      expect(updated.enabled, false);
      expect(updated.scheduleTime, '10:00');
      expect(updated.lastRunAt, DateTime(2026, 4, 16, 10, 0));
      // Unchanged fields
      expect(updated.id, testTask.id);
      expect(updated.accountId, testTask.accountId);
    });

    test('equality is based on id', () {
      final same = testTask.copyWith(scheduleTime: '12:00');
      final different = CheckInTask(
        id: 'other-id',
        accountId: 'account-id-1',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(testTask, equals(same));
      expect(testTask, isNot(equals(different)));
    });

    test('toString includes key fields', () {
      final str = testTask.toString();
      expect(str, contains('task-id-1'));
      expect(str, contains('account-id-1'));
      expect(str, contains('true'));
    });
  });
}
