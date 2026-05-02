import 'package:flutter_test/flutter_test.dart';
import 'package:fl_api_hub/core/network/dto/check_in_status_dto.dart';

void main() {
  group('CheckInStatusDto', () {
    test('parses nested New API status response correctly', () {
      final json = {
        'enabled': true,
        'max_quota': 100000,
        'min_quota': 1000,
        'stats': {
          'checked_in_today': true,
          'checkin_count': 5,
          'records': [
            {'checkin_date': '2026-05-01', 'quota_awarded': 500000},
            {'checkin_date': '2026-05-02', 'quota_awarded': 1083226},
          ],
          'total_checkins': 30,
          'total_quota': 500000.0,
        },
      };
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isTrue);
      expect(dto.checkedDays, [1, 2]);
      expect(dto.totalReward, 500000.0);
    });

    test('parses checked_in_today false when not checked in', () {
      final json = {
        'enabled': true,
        'stats': {'checked_in_today': false, 'records': [], 'total_quota': 0},
      };
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isFalse);
      expect(dto.checkedDays, isEmpty);
      expect(dto.totalReward, 0.0);
    });

    test('parses empty stats gracefully', () {
      final json = {'enabled': true, 'stats': <String, dynamic>{}};
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isNull);
      expect(dto.checkedDays, isEmpty);
      expect(dto.totalReward, isNull);
    });

    test('handles missing stats field', () {
      final json = {'enabled': true};
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isNull);
      expect(dto.checkedDays, isEmpty);
      expect(dto.totalReward, isNull);
    });

    test('handles empty json', () {
      final json = <String, dynamic>{};
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isNull);
      expect(dto.checkedDays, isEmpty);
      expect(dto.totalReward, isNull);
    });

    test('extracts day numbers from checkin_date strings', () {
      final json = {
        'stats': {
          'checked_in_today': true,
          'records': [
            {'checkin_date': '2026-05-03', 'quota_awarded': 100},
            {'checkin_date': '2026-05-10', 'quota_awarded': 200},
            {'checkin_date': '2026-05-15', 'quota_awarded': 300},
          ],
          'total_quota': 600,
        },
      };
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedDays, [3, 10, 15]);
    });
  });
}
