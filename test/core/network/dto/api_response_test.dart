import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/core/network/dto/api_response.dart';

void main() {
  group('ApiResponse', () {
    test('success=true parses data via callback', () {
      final json = {
        'success': true,
        'message': 'ok',
        'data': {'value': 42},
      };
      final result = ApiResponse.fromJson<Map<String, dynamic>>(
        json,
        (data) => data,
      );
      expect(result.success, isTrue);
      expect(result.message, 'ok');
      expect(result.data, isNotNull);
      expect(result.data!['value'], 42);
    });

    test('success=false sets data=null even if data field present', () {
      final json = {
        'success': false,
        'message': 'error',
        'data': {'value': 42},
      };
      final result = ApiResponse.fromJson<Map<String, dynamic>>(
        json,
        (data) => data,
      );
      expect(result.success, isFalse);
      expect(result.data, isNull);
    });

    test('missing success defaults to false', () {
      final json = <String, dynamic>{};
      final result = ApiResponse.fromJson<Map<String, dynamic>>(
        json,
        (data) => data,
      );
      expect(result.success, isFalse);
    });

    test('message is preserved', () {
      final json = {'success': true, 'message': 'hello world'};
      final result = ApiResponse.fromJson<Map<String, dynamic>>(
        json,
        (data) => data,
      );
      expect(result.message, 'hello world');
    });

    test('data is null when success=true but data field is missing', () {
      final json = {'success': true, 'message': 'no data'};
      final result = ApiResponse.fromJson<Map<String, dynamic>>(
        json,
        (data) => data,
      );
      expect(result.success, isTrue);
      expect(result.data, isNull);
    });
  });
}
