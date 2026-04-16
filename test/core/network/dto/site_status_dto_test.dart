import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/site_status_dto.dart';

void main() {
  group('SiteStatusDto', () {
    test('all fields parsed with snake_case keys', () {
      final json = {
        'checkin_enabled': true,
        'version': 'v1.2.3',
        'system_name': 'Test System',
        'footer': 'Custom footer',
      };
      final dto = SiteStatusDto.fromJson(json);
      expect(dto.checkinEnabled, isTrue);
      expect(dto.version, 'v1.2.3');
      expect(dto.systemName, 'Test System');
      expect(dto.footer, 'Custom footer');
    });

    test('null fields', () {
      final json = <String, dynamic>{};
      final dto = SiteStatusDto.fromJson(json);
      expect(dto.checkinEnabled, isNull);
      expect(dto.version, isNull);
      expect(dto.systemName, isNull);
      expect(dto.footer, isNull);
    });
  });
}
