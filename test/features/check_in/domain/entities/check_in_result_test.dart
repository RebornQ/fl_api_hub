import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';

void main() {
  group('CheckInStatus', () {
    test('has three values', () {
      expect(CheckInStatus.values, hasLength(3));
      expect(CheckInStatus.values, contains(CheckInStatus.success));
      expect(CheckInStatus.values, contains(CheckInStatus.failed));
      expect(CheckInStatus.values, contains(CheckInStatus.skipped));
    });

    test('can be parsed from name', () {
      expect(CheckInStatus.values.byName('success'), CheckInStatus.success);
      expect(CheckInStatus.values.byName('failed'), CheckInStatus.failed);
      expect(CheckInStatus.values.byName('skipped'), CheckInStatus.skipped);
    });
  });

  group('CheckInResult', () {
    late CheckInResult successResult;
    late CheckInResult failedResult;
    late CheckInResult skippedResult;

    setUp(() {
      successResult = CheckInResult(
        id: 'result-id-1',
        taskId: 'task-id-1',
        accountId: 'account-id-1',
        status: CheckInStatus.success,
        message: 'Check-in successful!',
        rewardAmount: 0.5,
        executedAt: DateTime(2026, 4, 15, 8, 0),
      );

      failedResult = CheckInResult(
        id: 'result-id-2',
        taskId: 'task-id-1',
        accountId: 'account-id-1',
        status: CheckInStatus.failed,
        message: 'Network timeout',
        executedAt: DateTime(2026, 4, 15, 8, 0),
      );

      skippedResult = CheckInResult(
        id: 'result-id-3',
        taskId: 'task-id-1',
        accountId: 'account-id-1',
        status: CheckInStatus.skipped,
        message: 'Already checked in today',
        executedAt: DateTime(2026, 4, 15, 8, 0),
      );
    });

    test('success result has correct fields', () {
      expect(successResult.status, CheckInStatus.success);
      expect(successResult.message, 'Check-in successful!');
      expect(successResult.rewardAmount, 0.5);
      expect(successResult.isSuccess, true);
    });

    test('failed result has correct fields', () {
      expect(failedResult.status, CheckInStatus.failed);
      expect(failedResult.message, 'Network timeout');
      expect(failedResult.rewardAmount, isNull);
      expect(failedResult.isSuccess, false);
    });

    test('skipped result has correct fields', () {
      expect(skippedResult.status, CheckInStatus.skipped);
      expect(skippedResult.isSuccess, false);
    });

    test('constructs with minimal required fields', () {
      final result = CheckInResult(
        id: 'id',
        taskId: 'task-id',
        accountId: 'acc-id',
        status: CheckInStatus.success,
        executedAt: DateTime(2026),
      );

      expect(result.message, isNull);
      expect(result.rewardAmount, isNull);
    });

    test('equality is based on id', () {
      final same = CheckInResult(
        id: 'result-id-1',
        taskId: 'other-task',
        accountId: 'other-acc',
        status: CheckInStatus.failed,
        executedAt: DateTime(2026),
      );

      expect(successResult, equals(same));

      final different = CheckInResult(
        id: 'other-id',
        taskId: 'task-id-1',
        accountId: 'account-id-1',
        status: CheckInStatus.success,
        executedAt: DateTime(2026),
      );

      expect(successResult, isNot(equals(different)));
    });

    test('toString includes key fields', () {
      final str = successResult.toString();
      expect(str, contains('result-id-1'));
      expect(str, contains('success'));
      expect(str, contains('task-id-1'));
    });
  });
}
