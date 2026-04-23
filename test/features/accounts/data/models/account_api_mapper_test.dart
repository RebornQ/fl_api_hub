import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/core/network/dto/user_info_dto.dart';
import 'package:fl_all_api_hub/features/accounts/data/models/account_api_mapper.dart';

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

    group('extractUserId', () {
      test('returns id from dto', () {
        final dto = UserInfoDto(id: 42);
        expect(AccountApiMapper.extractUserId(dto), equals(42));
      });

      test('returns null when id is null', () {
        final dto = UserInfoDto();
        expect(AccountApiMapper.extractUserId(dto), isNull);
      });

      test('returns zero as-is (caller decides validity)', () {
        final dto = UserInfoDto(id: 0);
        expect(AccountApiMapper.extractUserId(dto), equals(0));
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

    group('computeBalance', () {
      test('returns explicit balance when dto provides it', () {
        final dto = UserInfoDto(balance: 12.34, quota: 999.0, usedQuota: 100.0);
        // Explicit balance wins even when quota math would give a different value.
        expect(AccountApiMapper.computeBalance(dto, 500000), equals(12.34));
      });

      test('derives balance from quota - usedQuota / quotaPerUnit', () {
        final dto = UserInfoDto(quota: 500000000, usedQuota: 1000000);
        // (500_000_000 - 1_000_000) / 500_000 = 998.0
        expect(AccountApiMapper.computeBalance(dto, 500000), equals(998.0));
      });

      test('uses site-reported quotaPerUnit override', () {
        final dto = UserInfoDto(quota: 2000000, usedQuota: 500000);
        // (2_000_000 - 500_000) / 250_000 = 6.0
        expect(AccountApiMapper.computeBalance(dto, 250000), equals(6.0));
      });

      test('returns null when quota is missing', () {
        final dto = UserInfoDto(usedQuota: 100.0);
        expect(AccountApiMapper.computeBalance(dto, 500000), isNull);
      });

      test('returns null when usedQuota is missing', () {
        final dto = UserInfoDto(quota: 1000.0);
        expect(AccountApiMapper.computeBalance(dto, 500000), isNull);
      });

      test('returns null when both quota and usedQuota missing', () {
        final dto = UserInfoDto();
        expect(AccountApiMapper.computeBalance(dto, 500000), isNull);
      });

      test('returns null when quotaPerUnit is zero', () {
        final dto = UserInfoDto(quota: 1000.0, usedQuota: 100.0);
        expect(AccountApiMapper.computeBalance(dto, 0), isNull);
      });

      test('returns null when quotaPerUnit is negative', () {
        final dto = UserInfoDto(quota: 1000.0, usedQuota: 100.0);
        expect(AccountApiMapper.computeBalance(dto, -1), isNull);
      });

      test('allows negative derived balance (overused quota)', () {
        final dto = UserInfoDto(quota: 1000.0, usedQuota: 2000.0);
        expect(AccountApiMapper.computeBalance(dto, 500), equals(-2.0));
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
        expect(AccountApiMapper.extractUserId(dto), equals(42));
        expect(AccountApiMapper.extractAccessToken(dto), equals('sk-token'));
      });
    });

    group('all extractors with empty dto', () {
      test('all return null when all fields are null', () {
        final dto = UserInfoDto();

        expect(AccountApiMapper.extractBalance(dto), isNull);
        expect(AccountApiMapper.extractUsername(dto), isNull);
        expect(AccountApiMapper.extractUserId(dto), isNull);
        expect(AccountApiMapper.extractAccessToken(dto), isNull);
      });
    });
  });
}
