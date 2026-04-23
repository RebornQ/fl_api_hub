import 'package:flutter_test/flutter_test.dart';

import 'package:fl_all_api_hub/features/check_in/data/models/check_in_mapper.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/check_in_result.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/check_in_task.dart';

void main() {
  group('CheckInTaskMapper', () {
    final createdAt = DateTime(2026, 1, 1, 0, 0, 0);
    final updatedAt = DateTime(2026, 4, 15, 12, 30, 0);
    final lastRunAt = DateTime(2026, 4, 15, 8, 0, 0);
    final nextRunAt = DateTime(2026, 4, 16, 8, 0, 0);

    test('toMap/fromMap roundtrip preserves all fields', () {
      final task = CheckInTask(
        id: 'task-1',
        accountId: 'acc-1',
        enabled: true,
        scheduleTime: '09:30',
        lastRunAt: lastRunAt,
        nextRunAt: nextRunAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = CheckInTaskMapper.toMap(task);
      final restored = CheckInTaskMapper.fromMap(map);

      expect(restored.id, task.id);
      expect(restored.accountId, task.accountId);
      expect(restored.enabled, task.enabled);
      expect(restored.scheduleTime, task.scheduleTime);
      expect(restored.lastRunAt, task.lastRunAt);
      expect(restored.nextRunAt, task.nextRunAt);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });

    test('fromMap handles null lastRunAt and nextRunAt', () {
      final map = {
        'id': 'task-2',
        'accountId': 'acc-2',
        'enabled': false,
        'scheduleTime': '10:00',
        'lastRunAt': null,
        'nextRunAt': null,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      final restored = CheckInTaskMapper.fromMap(map);

      expect(restored.lastRunAt, isNull);
      expect(restored.nextRunAt, isNull);
    });

    test('fromMap uses defaults when enabled and scheduleTime are missing', () {
      final map = {
        'id': 'task-3',
        'accountId': 'acc-3',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

      final restored = CheckInTaskMapper.fromMap(map);

      expect(restored.enabled, true);
      expect(restored.scheduleTime, '08:00');
    });
  });

  group('CheckInResultMapper', () {
    final executedAt = DateTime(2026, 4, 15, 8, 0, 5);

    test('toMap/fromMap roundtrip preserves all fields', () {
      final result = CheckInResult(
        id: 'result-1',
        taskId: 'task-1',
        accountId: 'acc-1',
        status: CheckInStatus.success,
        message: 'Checked in successfully',
        rewardAmount: 42.5,
        executedAt: executedAt,
      );

      final map = CheckInResultMapper.toMap(result);
      final restored = CheckInResultMapper.fromMap(map);

      expect(restored.id, result.id);
      expect(restored.taskId, result.taskId);
      expect(restored.accountId, result.accountId);
      expect(restored.status, result.status);
      expect(restored.message, result.message);
      expect(restored.rewardAmount, result.rewardAmount);
      expect(restored.executedAt, result.executedAt);
    });

    test('fromMap handles null message and rewardAmount', () {
      final map = {
        'id': 'result-2',
        'taskId': 'task-2',
        'accountId': 'acc-2',
        'status': 'failed',
        'message': null,
        'rewardAmount': null,
        'executedAt': executedAt.toIso8601String(),
      };

      final restored = CheckInResultMapper.fromMap(map);

      expect(restored.message, isNull);
      expect(restored.rewardAmount, isNull);
      expect(restored.status, CheckInStatus.failed);
    });

    test('CheckInStatus enum serializes by name', () {
      for (final status in CheckInStatus.values) {
        final result = CheckInResult(
          id: 'result-${status.name}',
          taskId: 'task-x',
          accountId: 'acc-x',
          status: status,
          executedAt: executedAt,
        );

        final map = CheckInResultMapper.toMap(result);

        expect(map['status'], status.name);

        final restored = CheckInResultMapper.fromMap(map);
        expect(restored.status, status);
      }
    });
  });
}
