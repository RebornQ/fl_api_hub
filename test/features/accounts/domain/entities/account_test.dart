import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/features/accounts/domain/entities/account.dart';

void main() {
  group('Account', () {
    late Account testAccount;

    setUp(() {
      testAccount = Account(
        id: 'test-id-1',
        name: 'Test Site',
        baseUrl: 'https://api.example.com',
        siteType: SiteType.newApi,
        authType: AuthType.accessToken,
        enabled: true,
        notes: 'Test notes',
        balance: 100.5,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    test('constructs with required fields', () {
      expect(testAccount.id, 'test-id-1');
      expect(testAccount.name, 'Test Site');
      expect(testAccount.baseUrl, 'https://api.example.com');
      expect(testAccount.siteType, SiteType.newApi);
      expect(testAccount.authType, AuthType.accessToken);
    });

    test('constructs with default values', () {
      final account = Account(
        id: 'id',
        name: 'name',
        baseUrl: 'https://example.com',
        siteType: SiteType.oneApi,
        authType: AuthType.cookie,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(account.enabled, true);
      expect(account.notes, isNull);
      expect(account.balance, isNull);
    });

    test('copyWith replaces specified fields', () {
      final updated = testAccount.copyWith(
        name: 'Updated Site',
        enabled: false,
        balance: 200.0,
      );

      expect(updated.name, 'Updated Site');
      expect(updated.enabled, false);
      expect(updated.balance, 200.0);
      // Unchanged fields
      expect(updated.id, testAccount.id);
      expect(updated.baseUrl, testAccount.baseUrl);
      expect(updated.siteType, testAccount.siteType);
    });

    test('equality is based on id', () {
      final same = testAccount.copyWith(name: 'Different Name');
      final different = Account(
        id: 'other-id',
        name: 'Test Site',
        baseUrl: 'https://api.example.com',
        siteType: SiteType.newApi,
        authType: AuthType.accessToken,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(testAccount, equals(same));
      expect(testAccount, isNot(equals(different)));
    });

    test('hashCode is consistent with equality', () {
      final same = testAccount.copyWith(name: 'Other');
      expect(testAccount.hashCode, same.hashCode);
    });

    test('toString includes key fields', () {
      final str = testAccount.toString();
      expect(str, contains('test-id-1'));
      expect(str, contains('Test Site'));
      expect(str, contains('SiteType'));
    });
  });
}
