import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/dto/user_info_dto.dart';
import 'package:all_api_hub_flutter/features/accounts/data/models/account_api_mapper.dart';

void main() {
  group('AccountApiMapper', () {
    group('extractBalance', () {
      test('returns balance from dto', () {
        final dto = UserInfoDto(balance: 123.45);
        expect(AccountApiMapper.extractBalance(dto), equals(123.45));
      });

      test('returns null when balance is null', () {
        final dto = UserInfoDto();
        expect(AccountApiMapper.extractBalance(dto), isNull);
      });

      test('returns zero balance', () {
        final dto = UserInfoDto(balance: 0.0);
        expect(AccountApiMapper.extractBalance(dto), equals(0.0));
      });
    });

    group('extractUsername', () {
      test('returns username from dto', () {
        final dto = UserInfoDto(username: 'testuser');
        expect(AccountApiMapper.extractUsername(dto), equals('testuser'));
      });

      test('returns null when username is null', () {
        final dto = UserInfoDto();
        expect(AccountApiMapper.extractUsername(dto), isNull);
      });
    });

    group('extractAccessToken', () {
      test('returns accessToken from dto', () {
        final dto = UserInfoDto(accessToken: 'sk-abc123');
        expect(AccountApiMapper.extractAccessToken(dto), equals('sk-abc123'));
      });

      test('returns null when accessToken is null', () {
        final dto = UserInfoDto();
        expect(AccountApiMapper.extractAccessToken(dto), isNull);
      });
    });

    group('all extractors with fully populated dto', () {
      test('returns all values correctly', () {
        final dto = UserInfoDto(
          id: 42,
          username: 'alice',
          email: 'alice@example.com',
          quota: 1000.0,
          usedQuota: 200.0,
          balance: 50.0,
          accessToken: 'sk-token',
          avatar: 'https://example.com/avatar.png',
        );

        expect(AccountApiMapper.extractBalance(dto), equals(50.0));
        expect(AccountApiMapper.extractUsername(dto), equals('alice'));
        expect(AccountApiMapper.extractAccessToken(dto), equals('sk-token'));
      });
    });

    group('all extractors with empty dto', () {
      test('all return null when all fields are null', () {
        final dto = UserInfoDto();

        expect(AccountApiMapper.extractBalance(dto), isNull);
        expect(AccountApiMapper.extractUsername(dto), isNull);
        expect(AccountApiMapper.extractAccessToken(dto), isNull);
      });
    });
  });
}
