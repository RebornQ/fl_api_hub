import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/access_token_dto.dart';

void main() {
  group('AccessTokenDto', () {
    test('parses token field', () {
      final json = {'token': 'abc123'};
      final dto = AccessTokenDto.fromJson(json);
      expect(dto.token, 'abc123');
    });

    test('falls back to key when token is null', () {
      final json = {'key': 'fallback-key'};
      final dto = AccessTokenDto.fromJson(json);
      expect(dto.token, 'fallback-key');
    });

    test('both null returns null token', () {
      final json = <String, dynamic>{};
      final dto = AccessTokenDto.fromJson(json);
      expect(dto.token, isNull);
    });
  });
}
