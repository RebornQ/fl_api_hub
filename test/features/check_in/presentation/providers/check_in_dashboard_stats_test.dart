import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_task.dart';
import 'package:all_api_hub_flutter/features/check_in/presentation/providers/check_in_providers.dart';

void main() {
  group('CheckInDashboardStats', () {
    group('from', () {
      test(
        'empty tasks and empty results yield zero counts and none status',
        () {
          final stats = CheckInDashboardStats.from(tasks: [], results: []);

          expect(stats.eligible, 0);
          expect(stats.executed, 0);
          expect(stats.successCount, 0);
          expect(stats.failedCount, 0);
          expect(stats.skippedCount, 0);
          expect(stats.nextRunAt, isNull);
          expect(stats.lastRunAt, isNull);
          expect(stats.overallStatus, CheckInOverallStatus.none);
        },
      );

      test('two enabled tasks, one success result', () {
        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final task2 = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result1 = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.success,
          executedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1, task2],
          results: [result1],
        );

        expect(stats.eligible, 2);
        expect(stats.executed, 1);
        expect(stats.successCount, 1);
        expect(stats.failedCount, 0);
        expect(stats.skippedCount, 0);
        expect(stats.overallStatus, CheckInOverallStatus.allSuccess);
      });

      test('all failed results yield allFailed status', () {
        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result1 = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.failed,
          executedAt: DateTime(2026, 1, 1),
        );
        final result2 = CheckInResult(
          id: 'r2',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.failed,
          executedAt: DateTime(2026, 1, 2),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1],
          results: [result1, result2],
        );

        expect(stats.failedCount, 2);
        expect(stats.successCount, 0);
        expect(stats.overallStatus, CheckInOverallStatus.allFailed);
      });

      test('mixed results yield partial status', () {
        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result1 = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.success,
          executedAt: DateTime(2026, 1, 1),
        );
        final result2 = CheckInResult(
          id: 'r2',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.failed,
          executedAt: DateTime(2026, 1, 2),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1],
          results: [result1, result2],
        );

        expect(stats.successCount, 1);
        expect(stats.failedCount, 1);
        expect(stats.overallStatus, CheckInOverallStatus.partial);
      });

      test('all success results yield allSuccess status', () {
        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final task2 = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result1 = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.success,
          executedAt: DateTime(2026, 1, 1),
        );
        final result2 = CheckInResult(
          id: 'r2',
          taskId: 't2',
          accountId: 'a2',
          status: CheckInStatus.success,
          executedAt: DateTime(2026, 1, 2),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1, task2],
          results: [result1, result2],
        );

        expect(stats.successCount, 2);
        expect(stats.failedCount, 0);
        expect(stats.overallStatus, CheckInOverallStatus.allSuccess);
      });

      test('nextRunAt picks earliest among enabled tasks', () {
        final early = DateTime(2026, 3, 1, 8, 0);
        final late = DateTime(2026, 3, 1, 16, 0);

        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          nextRunAt: late,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final task2 = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: true,
          nextRunAt: early,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1, task2],
          results: [],
        );

        expect(stats.nextRunAt, early);
      });

      test('lastRunAt picks latest across all tasks', () {
        final early = DateTime(2026, 3, 1, 8, 0);
        final late = DateTime(2026, 3, 1, 16, 0);

        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          lastRunAt: early,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final task2 = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: false,
          lastRunAt: late,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1, task2],
          results: [],
        );

        expect(stats.lastRunAt, late);
      });

      test('disabled tasks are not counted in eligible', () {
        final enabledTask = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final disabledTask = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [enabledTask, disabledTask],
          results: [],
        );

        expect(stats.eligible, 1);
      });

      test('nextRunAt ignores disabled tasks', () {
        final early = DateTime(2026, 3, 1, 8, 0);
        final late = DateTime(2026, 3, 1, 16, 0);

        final disabledTask = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: false,
          nextRunAt: early,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final enabledTask = CheckInTask(
          id: 't2',
          accountId: 'a2',
          enabled: true,
          nextRunAt: late,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [disabledTask, enabledTask],
          results: [],
        );

        // Should pick the late time from enabled task, ignoring early from disabled
        expect(stats.nextRunAt, late);
      });

      test('skipped results are counted correctly', () {
        final task1 = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result1 = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.skipped,
          executedAt: DateTime(2026, 1, 1),
        );
        final result2 = CheckInResult(
          id: 'r2',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.skipped,
          executedAt: DateTime(2026, 1, 2),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task1],
          results: [result1, result2],
        );

        expect(stats.skippedCount, 2);
        expect(stats.successCount, 0);
        expect(stats.failedCount, 0);
        // Only skipped (no success, no failure) -> none
        expect(stats.overallStatus, CheckInOverallStatus.none);
      });

      test('overallStatus is none when results contain only skipped', () {
        final task = CheckInTask(
          id: 't1',
          accountId: 'a1',
          enabled: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result = CheckInResult(
          id: 'r1',
          taskId: 't1',
          accountId: 'a1',
          status: CheckInStatus.skipped,
          executedAt: DateTime(2026, 1, 1),
        );

        final stats = CheckInDashboardStats.from(
          tasks: [task],
          results: [result],
        );

        expect(stats.overallStatus, CheckInOverallStatus.none);
      });
    });
  });
}
