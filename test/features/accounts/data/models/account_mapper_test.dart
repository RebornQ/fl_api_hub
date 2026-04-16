import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/features/accounts/data/models/account_mapper.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';

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
        expect(map['createdAt'], equals(fixedCreatedAt.toIso8601String()));
        expect(map['updatedAt'], equals(fixedUpdatedAt.toIso8601String()));
      });

      test('serializes nullable fields as null', () {
        final account = createTestAccount(notes: null, balance: null);
        final map = AccountMapper.toMap(account);

        expect(map['notes'], isNull);
        expect(map['balance'], isNull);
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
    });

    group('roundtrip', () {
      test('toMap then fromMap preserves all fields', () {
        final original = createTestAccount();
        final map = AccountMapper.toMap(original);
        final restored = AccountMapper.fromMap(map);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.baseUrl, equals(original.baseUrl));
        expect(restored.siteType, equals(original.siteType));
        expect(restored.authType, equals(original.authType));
        expect(restored.enabled, equals(original.enabled));
        expect(restored.notes, equals(original.notes));
        expect(restored.balance, equals(original.balance));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.updatedAt, equals(original.updatedAt));
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
