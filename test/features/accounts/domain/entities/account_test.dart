import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/config/app_defaults.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/check_in_config.dart';

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

    test('constructs with default values for extended fields', () {
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
      // Username / userId are non-nullable with sentinel defaults
      // representing "unfilled" — `''` and `-1` respectively.
      expect(account.username, equals(''));
      expect(account.userId, equals(-1));
      expect(account.exchangeRate, kDefaultUsdToCnyRate);
      expect(account.manualBalanceUsd, isNull);
      expect(account.excludeFromTotalBalance, false);
      expect(account.tagIds, isEmpty);
      expect(account.checkIn, CheckInConfig.disabled);
      expect(account.redemptionUrl, isNull);
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

    test('copyWith replaces extended fields', () {
      final updated = testAccount.copyWith(
        username: 'admin',
        userId: 42,
        exchangeRate: 7.5,
        manualBalanceUsd: 9.9,
        excludeFromTotalBalance: true,
        tagIds: ['tag-1', 'tag-2'],
        checkIn: const CheckInConfig(autoCheckInEnabled: true),
        redemptionUrl: 'https://redeem.example.com',
      );

      expect(updated.username, 'admin');
      expect(updated.userId, 42);
      expect(updated.exchangeRate, 7.5);
      expect(updated.manualBalanceUsd, 9.9);
      expect(updated.excludeFromTotalBalance, true);
      expect(updated.tagIds, ['tag-1', 'tag-2']);
      expect(updated.checkIn.autoCheckInEnabled, true);
      expect(updated.redemptionUrl, 'https://redeem.example.com');
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

    test('deepEquals detects field-level changes', () {
      final same = Account(
        id: testAccount.id,
        name: testAccount.name,
        baseUrl: testAccount.baseUrl,
        siteType: testAccount.siteType,
        authType: testAccount.authType,
        enabled: testAccount.enabled,
        notes: testAccount.notes,
        balance: testAccount.balance,
        createdAt: testAccount.createdAt,
        updatedAt: testAccount.updatedAt,
      );
      expect(testAccount.deepEquals(same), isTrue);

      final renamed = testAccount.copyWith(name: 'Different');
      expect(testAccount.deepEquals(renamed), isFalse);

      final tagChanged = testAccount.copyWith(tagIds: ['t1']);
      expect(testAccount.deepEquals(tagChanged), isFalse);

      final checkInChanged = testAccount.copyWith(
        checkIn: const CheckInConfig(autoCheckInEnabled: true),
      );
      expect(testAccount.deepEquals(checkInChanged), isFalse);
    });

    test('toString includes key fields', () {
      final str = testAccount.toString();
      expect(str, contains('test-id-1'));
      expect(str, contains('Test Site'));
      expect(str, contains('SiteType'));
    });
  });

  group('CheckInConfig', () {
    test('disabled sentinel equals a default constructor instance', () {
      expect(CheckInConfig.disabled, const CheckInConfig());
      expect(CheckInConfig.disabled.autoCheckInEnabled, false);
      expect(CheckInConfig.disabled.customCheckInUrl, isNull);
    });

    test('copyWith replaces fields', () {
      const base = CheckInConfig.disabled;
      final enabled = base.copyWith(autoCheckInEnabled: true);
      expect(enabled.autoCheckInEnabled, true);
      expect(enabled.customCheckInUrl, isNull);

      final withUrl = enabled.copyWith(
        customCheckInUrl: 'https://welfare.example.com',
      );
      expect(withUrl.customCheckInUrl, 'https://welfare.example.com');
      expect(withUrl.autoCheckInEnabled, true);
    });

    test('withoutCustomCheckInUrl clears the URL explicitly', () {
      const original = CheckInConfig(
        autoCheckInEnabled: true,
        customCheckInUrl: 'https://welfare.example.com',
      );
      final cleared = original.withoutCustomCheckInUrl();
      expect(cleared.customCheckInUrl, isNull);
      expect(cleared.autoCheckInEnabled, true);
    });

    test('value equality', () {
      expect(
        const CheckInConfig(
          autoCheckInEnabled: true,
          customCheckInUrl: 'https://a',
        ),
        const CheckInConfig(
          autoCheckInEnabled: true,
          customCheckInUrl: 'https://a',
        ),
      );
      expect(
        const CheckInConfig(autoCheckInEnabled: true),
        isNot(const CheckInConfig(autoCheckInEnabled: false)),
      );
    });
  });
}
