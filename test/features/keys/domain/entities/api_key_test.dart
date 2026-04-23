import 'package:flutter_test/flutter_test.dart';

import 'package:fl_all_api_hub/features/keys/domain/entities/api_key.dart';

void main() {
  group('ApiKey', () {
    late ApiKey testKey;

    setUp(() {
      testKey = ApiKey(
        id: 'key-id-1',
        accountId: 'account-id-1',
        name: 'Test Key',
        quota: 1000,
        usedQuota: 200,
        expiresAt: DateTime(2027, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
    });

    test('constructs with required fields', () {
      expect(testKey.id, 'key-id-1');
      expect(testKey.accountId, 'account-id-1');
      expect(testKey.name, 'Test Key');
      expect(testKey.quota, 1000);
      expect(testKey.usedQuota, 200);
    });

    test('constructs with default values', () {
      final key = ApiKey(
        id: 'id',
        accountId: 'acc-id',
        name: 'name',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(key.usedQuota, 0);
      expect(key.quota, isNull);
      expect(key.expiresAt, isNull);
    });

    test('remainingQuota calculates correctly', () {
      expect(testKey.remainingQuota, 800);

      final unlimited = ApiKey(
        id: 'id',
        accountId: 'acc-id',
        name: 'unlimited',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(unlimited.remainingQuota, isNull);
    });

    test('isExpired returns correct value', () {
      // Key with future expiration
      expect(testKey.isExpired, false);

      // Key with past expiration
      final expired = testKey.copyWith(expiresAt: DateTime(2020, 1, 1));
      expect(expired.isExpired, true);

      // Key with no expiration
      final noExpiry = ApiKey(
        id: 'id',
        accountId: 'acc-id',
        name: 'no-expiry',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(noExpiry.isExpired, false);
    });

    test('copyWith replaces specified fields', () {
      final updated = testKey.copyWith(name: 'Updated Key', usedQuota: 500);

      expect(updated.name, 'Updated Key');
      expect(updated.usedQuota, 500);
      expect(updated.id, testKey.id);
      expect(updated.accountId, testKey.accountId);
    });

    test('equality is based on id', () {
      final same = testKey.copyWith(name: 'Different');
      final different = ApiKey(
        id: 'other-id',
        accountId: 'account-id-1',
        name: 'Test Key',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(testKey, equals(same));
      expect(testKey, isNot(equals(different)));
    });

    test('toString includes key fields', () {
      final str = testKey.toString();
      expect(str, contains('key-id-1'));
      expect(str, contains('Test Key'));
      expect(str, contains('account-id-1'));
    });
  });
}
