import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/user_info_dto.dart';

void main() {
  group('UserInfoDto', () {
    test('all fields parsed correctly', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'quota': 1000.5,
        'used_quota': 200.3,
        'balance': 800.2,
        'access_token': 'tok_abc123',
        'avatar': 'https://example.com/avatar.png',
      };
      final dto = UserInfoDto.fromJson(json);
      expect(dto.id, 1);
      expect(dto.username, 'testuser');
      expect(dto.email, 'test@example.com');
      expect(dto.quota, 1000.5);
      expect(dto.usedQuota, 200.3);
      expect(dto.balance, 800.2);
      expect(dto.accessToken, 'tok_abc123');
      expect(dto.avatar, 'https://example.com/avatar.png');
    });

    test('num to double coercion for quota/usedQuota/balance', () {
      final json = {'quota': 100, 'used_quota': 50, 'balance': 200};
      final dto = UserInfoDto.fromJson(json);
      expect(dto.quota, 100.0);
      expect(dto.usedQuota, 50.0);
      expect(dto.balance, 200.0);
    });

    test('null fields', () {
      final json = {'id': 1, 'username': 'testuser'};
      final dto = UserInfoDto.fromJson(json);
      expect(dto.id, 1);
      expect(dto.username, 'testuser');
      expect(dto.email, isNull);
      expect(dto.quota, isNull);
      expect(dto.usedQuota, isNull);
      expect(dto.balance, isNull);
      expect(dto.accessToken, isNull);
      expect(dto.avatar, isNull);
    });

    test('empty json returns all-null dto', () {
      final json = <String, dynamic>{};
      final dto = UserInfoDto.fromJson(json);
      expect(dto.id, isNull);
      expect(dto.username, isNull);
      expect(dto.email, isNull);
      expect(dto.quota, isNull);
      expect(dto.usedQuota, isNull);
      expect(dto.balance, isNull);
      expect(dto.accessToken, isNull);
      expect(dto.avatar, isNull);
    });
  });
}
