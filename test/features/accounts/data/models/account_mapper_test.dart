import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/core/config/app_defaults.dart';
import 'package:fl_all_api_hub/core/network/site_type.dart';
import 'package:fl_all_api_hub/features/accounts/data/models/account_mapper.dart';
import 'package:fl_all_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_all_api_hub/features/accounts/domain/entities/check_in_config.dart';

void main() {
  group('AccountMapper', () {
    final fixedCreatedAt = DateTime(2025, 1, 15, 10, 30, 0);
    final fixedUpdatedAt = DateTime(2025, 3, 20, 14, 45, 0);

    Account createTestAccount({
      bool enabled = true,
      String? notes = 'some notes',
      double? balance = 99.5,
      SiteType siteType = SiteType.newApi,
      AuthType authType = AuthType.accessToken,
      String? username,
      int? userId,
      double exchangeRate = kDefaultUsdToCnyRate,
      double? manualBalanceUsd,
      bool excludeFromTotalBalance = false,
      List<String> tagIds = const [],
      CheckInConfig checkIn = CheckInConfig.disabled,
      String? redemptionUrl,
    }) {
      return Account(
        id: 'acc-001',
        name: 'Test Account',
        baseUrl: 'https://api.example.com',
        siteType: siteType,
        authType: authType,
        enabled: enabled,
        notes: notes,
        balance: balance,
        // Username / userId became non-nullable on the entity; null here is
        // translated to the "unfilled" sentinels the entity defines.
        username: username ?? '',
        userId: userId ?? -1,
        exchangeRate: exchangeRate,
        manualBalanceUsd: manualBalanceUsd,
        excludeFromTotalBalance: excludeFromTotalBalance,
        tagIds: tagIds,
        checkIn: checkIn,
        redemptionUrl: redemptionUrl,
        createdAt: fixedCreatedAt,
        updatedAt: fixedUpdatedAt,
      );
    }

    group('toMap', () {
      test('serializes SiteType as string value', () {
        final account = createTestAccount(siteType: SiteType.oneApi);
        final map = AccountMapper.toMap(account);

        expect(map['siteType'], equals('one-api'));
      });

      test('serializes AuthType as enum name', () {
        final account = createTestAccount(authType: AuthType.cookie);
        final map = AccountMapper.toMap(account);

        expect(map['authType'], equals('cookie'));
      });

      test('serializes all fields correctly', () {
        final account = createTestAccount();
        final map = AccountMapper.toMap(account);

        expect(map['id'], equals('acc-001'));
        expect(map['name'], equals('Test Account'));
        expect(map['baseUrl'], equals('https://api.example.com'));
        expect(map['siteType'], equals('new-api'));
        expect(map['authType'], equals('accessToken'));
        expect(map['enabled'], isTrue);
        expect(map['notes'], equals('some notes'));
        expect(map['balance'], equals(99.5));
        expect(map['exchangeRate'], equals(kDefaultUsdToCnyRate));
        expect(map['excludeFromTotalBalance'], isFalse);
        expect(map['tagIds'], isEmpty);
        expect(map['checkIn'], isMap);
        expect((map['checkIn'] as Map)['autoCheckInEnabled'], isFalse);
        expect(map['createdAt'], equals(fixedCreatedAt.toIso8601String()));
        expect(map['updatedAt'], equals(fixedUpdatedAt.toIso8601String()));
      });

      test('serializes extended fields correctly', () {
        final account = createTestAccount(
          username: 'admin',
          userId: 99,
          exchangeRate: 7.5,
          manualBalanceUsd: 12.5,
          excludeFromTotalBalance: true,
          tagIds: const ['tag-1', 'tag-2'],
          checkIn: const CheckInConfig(
            autoCheckInEnabled: true,
            customCheckInUrl: 'https://welfare.example.com',
          ),
          redemptionUrl: 'https://redeem.example.com',
        );
        final map = AccountMapper.toMap(account);

        expect(map['username'], equals('admin'));
        expect(map['userId'], equals(99));
        expect(map['exchangeRate'], equals(7.5));
        expect(map['manualBalanceUsd'], equals(12.5));
        expect(map['excludeFromTotalBalance'], isTrue);
        expect(map['tagIds'], equals(['tag-1', 'tag-2']));
        final checkIn = map['checkIn'] as Map;
        expect(checkIn['autoCheckInEnabled'], isTrue);
        expect(
          checkIn['customCheckInUrl'],
          equals('https://welfare.example.com'),
        );
        expect(map['redemptionUrl'], equals('https://redeem.example.com'));
      });

      test('serializes nullable fields as null', () {
        final account = createTestAccount(notes: null, balance: null);
        final map = AccountMapper.toMap(account);

        expect(map['notes'], isNull);
        expect(map['balance'], isNull);
        // Username / userId are non-nullable on the entity; unfilled values
        // round-trip as the sentinel (`''` and `-1`) rather than null.
        expect(map['username'], equals(''));
        expect(map['userId'], equals(-1));
        expect(map['manualBalanceUsd'], isNull);
        expect(map['redemptionUrl'], isNull);
      });
    });

    group('fromMap', () {
      test('deserializes full data correctly', () {
        final map = <String, dynamic>{
          'id': 'acc-001',
          'name': 'Test Account',
          'baseUrl': 'https://api.example.com',
          'siteType': 'new-api',
          'authType': 'accessToken',
          'enabled': true,
          'notes': 'some notes',
          'balance': 99.5,
          'username': 'admin',
          'userId': 88291,
          'exchangeRate': 7.5,
          'manualBalanceUsd': 12.5,
          'excludeFromTotalBalance': true,
          'tagIds': ['tag-1', 'tag-2'],
          'checkIn': {
            'autoCheckInEnabled': true,
            'customCheckInUrl': 'https://welfare.example.com',
          },
          'redemptionUrl': 'https://redeem.example.com',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final account = AccountMapper.fromMap(map);

        expect(account.id, equals('acc-001'));
        expect(account.name, equals('Test Account'));
        expect(account.baseUrl, equals('https://api.example.com'));
        expect(account.siteType, equals(SiteType.newApi));
        expect(account.authType, equals(AuthType.accessToken));
        expect(account.enabled, isTrue);
        expect(account.notes, equals('some notes'));
        expect(account.balance, equals(99.5));
        expect(account.username, equals('admin'));
        expect(account.userId, equals(88291));
        expect(account.exchangeRate, equals(7.5));
        expect(account.manualBalanceUsd, equals(12.5));
        expect(account.excludeFromTotalBalance, isTrue);
        expect(account.tagIds, equals(['tag-1', 'tag-2']));
        expect(account.checkIn.autoCheckInEnabled, isTrue);
        expect(
          account.checkIn.customCheckInUrl,
          equals('https://welfare.example.com'),
        );
        expect(account.redemptionUrl, equals('https://redeem.example.com'));
        expect(account.createdAt, equals(fixedCreatedAt));
        expect(account.updatedAt, equals(fixedUpdatedAt));
      });

      test('defaults enabled to true when missing', () {
        final map = <String, dynamic>{
          'id': 'acc-002',
          'name': 'Minimal',
          'baseUrl': 'https://minimal.com',
          'siteType': 'one-api',
          'authType': 'cookie',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final account = AccountMapper.fromMap(map);

        expect(account.enabled, isTrue);
      });

      test('handles null notes and balance', () {
        final map = <String, dynamic>{
          'id': 'acc-003',
          'name': 'No Extras',
          'baseUrl': 'https://no-extras.com',
          'siteType': 'new-api',
          'authType': 'none',
          'enabled': false,
          'notes': null,
          'balance': null,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final account = AccountMapper.fromMap(map);

        expect(account.notes, isNull);
        expect(account.balance, isNull);
      });

      test('deserializes legacy payload without extended fields', () {
        final legacyMap = <String, dynamic>{
          'id': 'legacy',
          'name': 'Legacy',
          'baseUrl': 'https://legacy.example.com',
          'siteType': 'new-api',
          'authType': 'accessToken',
          'enabled': true,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final account = AccountMapper.fromMap(legacyMap);

        // Legacy payloads predate the required username / userId fields;
        // they rehydrate with the entity sentinels so the editor can
        // prompt the user to backfill them.
        expect(account.username, equals(''));
        expect(account.userId, equals(-1));
        expect(account.exchangeRate, kDefaultUsdToCnyRate);
        expect(account.manualBalanceUsd, isNull);
        expect(account.excludeFromTotalBalance, isFalse);
        expect(account.tagIds, isEmpty);
        expect(account.checkIn, CheckInConfig.disabled);
        expect(account.redemptionUrl, isNull);
      });

      test('parses stringified userId for forward compatibility', () {
        final map = <String, dynamic>{
          'id': 'acc-str-id',
          'name': 'String UserId',
          'baseUrl': 'https://example.com',
          'siteType': 'new-api',
          'authType': 'accessToken',
          'userId': '4242',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };
        final account = AccountMapper.fromMap(map);
        expect(account.userId, equals(4242));
      });

      test('tolerates malformed tagIds by returning an empty list', () {
        final map = <String, dynamic>{
          'id': 'acc-bad-tags',
          'name': 'Bad Tags',
          'baseUrl': 'https://example.com',
          'siteType': 'new-api',
          'authType': 'accessToken',
          'tagIds': 'not-a-list',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };
        final account = AccountMapper.fromMap(map);
        expect(account.tagIds, isEmpty);
      });

      test('deserializes all SiteType values', () {
        for (final siteType in SiteType.values) {
          final map = <String, dynamic>{
            'id': 'acc-st',
            'name': 'SiteType Test',
            'baseUrl': 'https://example.com',
            'siteType': siteType.value,
            'authType': 'accessToken',
            'enabled': true,
            'createdAt': fixedCreatedAt.toIso8601String(),
            'updatedAt': fixedUpdatedAt.toIso8601String(),
          };

          final account = AccountMapper.fromMap(map);
          expect(account.siteType, equals(siteType));
        }
      });

      test('deserializes all AuthType values', () {
        for (final authType in AuthType.values) {
          final map = <String, dynamic>{
            'id': 'acc-at',
            'name': 'AuthType Test',
            'baseUrl': 'https://example.com',
            'siteType': 'new-api',
            'authType': authType.name,
            'enabled': true,
            'createdAt': fixedCreatedAt.toIso8601String(),
            'updatedAt': fixedUpdatedAt.toIso8601String(),
          };

          final account = AccountMapper.fromMap(map);
          expect(account.authType, equals(authType));
        }
      });

      test('coerces unknown siteType string to SiteType.unknown', () {
        // Legacy records or retired backends may carry a siteType value that
        // no longer matches any enum entry; the mapper must fall back to
        // SiteType.unknown instead of throwing.
        final map = <String, dynamic>{
          'id': 'acc-legacy-type',
          'name': 'Retired Backend',
          'baseUrl': 'https://legacy.example.com',
          'siteType': 'this-backend-no-longer-exists',
          'authType': 'accessToken',
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final account = AccountMapper.fromMap(map);
        expect(account.siteType, equals(SiteType.unknown));
      });
    });

    group('roundtrip', () {
      test('toMap then fromMap preserves all fields', () {
        final original = createTestAccount(
          username: 'admin',
          userId: 99,
          exchangeRate: 7.9,
          manualBalanceUsd: 5.5,
          excludeFromTotalBalance: true,
          tagIds: const ['t1', 't2'],
          checkIn: const CheckInConfig(
            autoCheckInEnabled: true,
            customCheckInUrl: 'https://welfare.example.com',
          ),
          redemptionUrl: 'https://redeem.example.com',
        );
        final map = AccountMapper.toMap(original);
        final restored = AccountMapper.fromMap(map);

        expect(restored.deepEquals(original), isTrue);
      });

      test(
        'toMap then fromMap preserves fields with null notes and balance',
        () {
          final original = createTestAccount(notes: null, balance: null);
          final map = AccountMapper.toMap(original);
          final restored = AccountMapper.fromMap(map);

          expect(restored.notes, isNull);
          expect(restored.balance, isNull);
          expect(restored.id, equals(original.id));
          expect(restored.name, equals(original.name));
        },
      );
    });
  });
}
