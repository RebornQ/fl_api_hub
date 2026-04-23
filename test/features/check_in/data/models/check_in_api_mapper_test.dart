import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/core/network/dto/check_in_result_dto.dart';
import 'package:fl_all_api_hub/core/network/dto/check_in_data_dto.dart';
import 'package:fl_all_api_hub/features/check_in/data/models/check_in_api_mapper.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/check_in_result.dart';

void main() {
  group('CheckInApiMapper', () {
    group('inferStatus', () {
      test('returns success when success is true', () {
        final dto = CheckInResultDto(
          success: true,
          message: '签到成功',
          data: CheckInDataDto(checkinDate: '2026-04-23', quotaAwarded: 1000),
        );
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.success);
      });

      test(
        'returns alreadyChecked when success is false and message contains "已签到"',
        () {
          final dto = CheckInResultDto(success: false, message: '今日已签到');
          expect(
            CheckInApiMapper.inferStatus(dto),
            CheckInStatus.alreadyChecked,
          );
        },
      );

      test(
        'returns alreadyChecked when success is false and message contains "already"',
        () {
          final dto = CheckInResultDto(
            success: false,
            message: 'Already checked in',
          );
          expect(
            CheckInApiMapper.inferStatus(dto),
            CheckInStatus.alreadyChecked,
          );
        },
      );

      test('returns failed when success is false with other error message', () {
        final dto = CheckInResultDto(success: false, message: '签到失败,请稍后重试');
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });

      test('returns failed when success is false and message is null', () {
        final dto = CheckInResultDto(success: false, message: null);
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.failed);
      });

      test('returns success even when data is null', () {
        final dto = CheckInResultDto(
          success: true,
          message: '签到成功',
          data: null,
        );
        expect(CheckInApiMapper.inferStatus(dto), CheckInStatus.success);
      });
    });

    group('toEntity', () {
      test('maps all fields correctly with complete data', () {
        final dto = CheckInResultDto(
          success: true,
          message: '签到成功',
          data: CheckInDataDto(
            checkinDate: '2026-04-23',
            quotaAwarded: 1083226,
          ),
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
        expect(result.message, '签到成功');
        expect(result.rewardAmount, 1083226.0);
        expect(result.checkinDate, '2026-04-23');
        expect(result.quotaAwarded, 1083226);
        expect(result.executedAt, isNotNull);
      });

      test('handles null data field', () {
        final dto = CheckInResultDto(
          success: true,
          message: '签到成功',
          data: null,
        );
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: 'task-123',
          accountId: 'account-456',
          resultId: 'result-789',
        );

        expect(result.rewardAmount, isNull);
        expect(result.checkinDate, isNull);
        expect(result.quotaAwarded, isNull);
      });

      test('maps alreadyChecked status correctly', () {
        final dto = CheckInResultDto(success: false, message: '今日已签到');
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: 'task-123',
          accountId: 'account-456',
          resultId: 'result-789',
        );

        expect(result.status, CheckInStatus.alreadyChecked);
        expect(result.message, '今日已签到');
      });

      test('maps failed status correctly', () {
        final dto = CheckInResultDto(success: false, message: '签到失败,请稍后重试');
        final result = CheckInApiMapper.toEntity(
          dto,
          taskId: 'task-123',
          accountId: 'account-456',
          resultId: 'result-789',
        );

        expect(result.status, CheckInStatus.failed);
        expect(result.message, '签到失败,请稍后重试');
      });
    });
  });
}
