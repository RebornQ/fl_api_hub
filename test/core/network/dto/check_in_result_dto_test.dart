import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/check_in_result_dto.dart';

void main() {
  group('CheckInResultDto', () {
    test('all fields parsed correctly', () {
      final json = {'message': 'Check-in successful', 'reward': 0.5};
      final dto = CheckInResultDto.fromJson(json);
      expect(dto.message, 'Check-in successful');
      expect(dto.reward, 0.5);
    });

    test('null fields', () {
      final json = <String, dynamic>{};
      final dto = CheckInResultDto.fromJson(json);
      expect(dto.message, isNull);
      expect(dto.reward, isNull);
    });

    test('num to double coercion for reward', () {
      final json = {'reward': 10};
      final dto = CheckInResultDto.fromJson(json);
      expect(dto.reward, 10.0);
    });
  });
}
