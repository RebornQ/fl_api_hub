import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/check_in_result_dto.dart';
import 'package:all_api_hub_flutter/core/network/dto/check_in_data_dto.dart';

void main() {
  group('CheckInResultDto', () {
    test('parses successful check-in with data', () {
      final json = {
        'data': {'checkin_date': '2026-04-23', 'quota_awarded': 1083226},
        'message': '签到成功',
        'success': true,
      };

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, true);
      expect(dto.message, '签到成功');
      expect(dto.data, isNotNull);
      expect(dto.data!.checkinDate, '2026-04-23');
      expect(dto.data!.quotaAwarded, 1083226);
    });

    test('parses already checked in response', () {
      final json = {'message': '今日已签到', 'success': false};

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, false);
      expect(dto.message, '今日已签到');
      expect(dto.data, isNull);
    });

    test('parses failed check-in response', () {
      final json = {'message': '签到失败,请稍后重试', 'success': false};

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, false);
      expect(dto.message, '签到失败,请稍后重试');
      expect(dto.data, isNull);
    });

    test('handles missing data field', () {
      final json = {'message': '签到成功', 'success': true};

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, true);
      expect(dto.message, '签到成功');
      expect(dto.data, isNull);
    });

    test('handles missing message field', () {
      final json = {
        'data': {'checkin_date': '2026-04-23', 'quota_awarded': 500},
        'success': true,
      };

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, true);
      expect(dto.message, isNull);
      expect(dto.data, isNotNull);
    });

    test('defaults success to false when missing', () {
      final json = {'message': 'some message'};

      final dto = CheckInResultDto.fromJson(json);

      expect(dto.success, false);
      expect(dto.message, 'some message');
    });
  });

  group('CheckInDataDto', () {
    test('parses complete data', () {
      final json = {'checkin_date': '2026-04-23', 'quota_awarded': 1083226};

      final dto = CheckInDataDto.fromJson(json);

      expect(dto.checkinDate, '2026-04-23');
      expect(dto.quotaAwarded, 1083226);
    });

    test('handles missing fields', () {
      final json = <String, dynamic>{};

      final dto = CheckInDataDto.fromJson(json);

      expect(dto.checkinDate, isNull);
      expect(dto.quotaAwarded, isNull);
    });
  });
}
