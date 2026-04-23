import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/core/network/dto/check_in_status_dto.dart';

void main() {
  group('CheckInStatusDto', () {
    test('all fields parsed correctly', () {
      final json = {
        'checked_in_today': true,
        'checked_days': [1, 5, 10, 15],
        'total_reward': 2.5,
      };
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isTrue);
      expect(dto.checkedDays, [1, 5, 10, 15]);
      expect(dto.totalReward, 2.5);
    });

    test('checked_days list is parsed', () {
      final json = {
        'checked_days': [1, 2, 3],
      };
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedDays, isNotNull);
      expect(dto.checkedDays, hasLength(3));
      expect(dto.checkedDays, containsAll([1, 2, 3]));
    });

    test('null fields', () {
      final json = {'checked_in_today': false};
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isFalse);
      expect(dto.checkedDays, isNull);
      expect(dto.totalReward, isNull);
    });

    test('empty json returns all-null dto', () {
      final json = <String, dynamic>{};
      final dto = CheckInStatusDto.fromJson(json);
      expect(dto.checkedInToday, isNull);
      expect(dto.checkedDays, isNull);
      expect(dto.totalReward, isNull);
    });
  });
}
