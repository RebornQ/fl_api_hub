import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/check_in_result_dto.dart';
import 'package:all_api_hub_flutter/features/check_in/data/models/check_in_api_mapper.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';

void main() {
  group('CheckInApiMapper', () {
    group('inferStatus', () {
      test('returns success when reward is greater than 0', () {
        final dto = CheckInResultDto(reward: 5.0, message: 'ok');
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.success);
      });

      test('returns failed when reward is 0 and message is null', () {
        final dto = CheckInResultDto(reward: 0, message: null);
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });

      test('returns skipped when message contains "already"', () {
        final dto = CheckInResultDto(
          reward: null,
          message: 'Already checked in',
        );
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.skipped);
      });

      test(
        'returns skipped when message contains Chinese already-checked-in text',
        () {
          final dto = CheckInResultDto(reward: null, message: '今日已签到');
          expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.skipped);
        },
      );

      test('returns success for non-error message without reward', () {
        final dto = CheckInResultDto(
          reward: null,
          message: 'Check-in successful',
        );
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.success);
      });

      test('returns failed when message contains "fail"', () {
        final dto = CheckInResultDto(reward: null, message: 'Request failed');
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });

      test('returns failed when message contains "error"', () {
        final dto = CheckInResultDto(
          reward: null,
          message: 'Server error occurred',
        );
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });

      test('returns failed when both message and reward are null', () {
        final dto = CheckInResultDto(reward: null, message: null);
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });
    });

    group('toEntity', () {
      test('maps all fields correctly', () {
        final dto = CheckInResultDto(
          message: 'Check-in successful',
          reward: 1.5,
        );
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: 'task-123',
          accountId: 'account-456',
          resultId: 'result-789',
        );

        expect(result.id, 'result-789');
        expect(result.taskId, 'task-123');
        expect(result.accountId, 'account-456');
        expect(result.status, CheckInStatus.success);
        expect(result.message, 'Check-in successful');
        expect(result.rewardAmount, 1.5);
        expect(result.executedAt, isNotNull);
      });

      test('uses provided taskId, accountId, and resultId', () {
        final dto = CheckInResultDto(message: 'ok', reward: 2.0);
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: 'my-task',
          accountId: 'my-account',
          resultId: 'my-result',
        );

        expect(result.taskId, 'my-task');
        expect(result.accountId, 'my-account');
        expect(result.id, 'my-result');
      });
    });
  });
}
