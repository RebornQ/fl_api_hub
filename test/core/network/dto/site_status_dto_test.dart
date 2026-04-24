import 'package:flutter_test/flutter_test.dart';
import 'package:fl_api_hub/core/network/dto/site_status_dto.dart';

void main() {
  group('SiteStatusDto', () {
    test('all fields parsed with snake_case keys', () {
      final json = {
        'checkin_enabled': true,
        'version': 'v1.2.3',
        'system_name': 'Test System',
        'footer': 'Custom footer',
        'quota_per_unit': 500000,
      };
      final dto = SiteStatusDto.fromJson(json);
      expect(dto.checkinEnabled, isTrue);
      expect(dto.version, 'v1.2.3');
      expect(dto.systemName, 'Test System');
      expect(dto.footer, 'Custom footer');
      expect(dto.quotaPerUnit, equals(500000.0));
    });

    test('null fields', () {
      final json = <String, dynamic>{};
      final dto = SiteStatusDto.fromJson(json);
      expect(dto.checkinEnabled, isNull);
      expect(dto.version, isNull);
      expect(dto.systemName, isNull);
      expect(dto.footer, isNull);
      expect(dto.quotaPerUnit, isNull);
    });

    group('quotaPerUnit', () {
      test('parses int quota_per_unit as double', () {
        final dto = SiteStatusDto.fromJson({'quota_per_unit': 500000});
        expect(dto.quotaPerUnit, equals(500000.0));
      });

      test('parses double quota_per_unit', () {
        final dto = SiteStatusDto.fromJson({'quota_per_unit': 250000.5});
        expect(dto.quotaPerUnit, equals(250000.5));
      });

      test('missing quota_per_unit yields null', () {
        final dto = SiteStatusDto.fromJson({'version': 'v1'});
        expect(dto.quotaPerUnit, isNull);
      });

      test('explicit null quota_per_unit yields null', () {
        final dto = SiteStatusDto.fromJson({'quota_per_unit': null});
        expect(dto.quotaPerUnit, isNull);
      });
    });
  });
}
