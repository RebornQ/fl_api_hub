import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/features/keys/data/models/api_key_mapper.dart';
import 'package:all_api_hub_flutter/features/keys/domain/entities/api_key.dart';

void main() {
  group('ApiKeyMapper', () {
    final fixedCreatedAt = DateTime(2025, 2, 10, 8, 0, 0);
    final fixedUpdatedAt = DateTime(2025, 4, 5, 16, 30, 0);
    final fixedExpiresAt = DateTime(2026, 12, 31, 23, 59, 59);

    ApiKey createTestApiKey({
      int? quota = 500,
      int usedQuota = 120,
      DateTime? expiresAt,
    }) {
      return ApiKey(
        id: 'key-001',
        accountId: 'acc-001',
        name: 'Test Key',
        quota: quota,
        usedQuota: usedQuota,
        expiresAt: expiresAt,
        createdAt: fixedCreatedAt,
        updatedAt: fixedUpdatedAt,
      );
    }

    group('toMap', () {
      test('serializes all fields correctly', () {
        final apiKey = createTestApiKey(expiresAt: fixedExpiresAt);
        final map = ApiKeyMapper.toMap(apiKey);

        expect(map['id'], equals('key-001'));
        expect(map['accountId'], equals('acc-001'));
        expect(map['name'], equals('Test Key'));
        expect(map['quota'], equals(500));
        expect(map['usedQuota'], equals(120));
        expect(map['expiresAt'], equals(fixedExpiresAt.toIso8601String()));
        expect(map['createdAt'], equals(fixedCreatedAt.toIso8601String()));
        expect(map['updatedAt'], equals(fixedUpdatedAt.toIso8601String()));
      });

      test('serializes null expiresAt as null', () {
        final apiKey = createTestApiKey(expiresAt: null);
        final map = ApiKeyMapper.toMap(apiKey);

        expect(map['expiresAt'], isNull);
      });

      test('serializes null quota as null', () {
        final apiKey = createTestApiKey(quota: null);
        final map = ApiKeyMapper.toMap(apiKey);

        expect(map['quota'], isNull);
      });
    });

    group('fromMap', () {
      test('deserializes full data correctly', () {
        final map = <String, dynamic>{
          'id': 'key-001',
          'accountId': 'acc-001',
          'name': 'Test Key',
          'quota': 500,
          'usedQuota': 120,
          'expiresAt': fixedExpiresAt.toIso8601String(),
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.id, equals('key-001'));
        expect(apiKey.accountId, equals('acc-001'));
        expect(apiKey.name, equals('Test Key'));
        expect(apiKey.quota, equals(500));
        expect(apiKey.usedQuota, equals(120));
        expect(apiKey.expiresAt, equals(fixedExpiresAt));
        expect(apiKey.createdAt, equals(fixedCreatedAt));
        expect(apiKey.updatedAt, equals(fixedUpdatedAt));
      });

      test('handles null expiresAt', () {
        final map = <String, dynamic>{
          'id': 'key-002',
          'accountId': 'acc-002',
          'name': 'No Expiry',
          'quota': 100,
          'usedQuota': 0,
          'expiresAt': null,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.expiresAt, isNull);
      });

      test('handles missing expiresAt key', () {
        final map = <String, dynamic>{
          'id': 'key-003',
          'accountId': 'acc-003',
          'name': 'Missing Expiry',
          'quota': 200,
          'usedQuota': 50,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.expiresAt, isNull);
      });

      test('defaults usedQuota to 0 when missing', () {
        final map = <String, dynamic>{
          'id': 'key-004',
          'accountId': 'acc-004',
          'name': 'No Used Quota',
          'quota': 300,
          'expiresAt': fixedExpiresAt.toIso8601String(),
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.usedQuota, equals(0));
      });

      test('defaults usedQuota to 0 when null', () {
        final map = <String, dynamic>{
          'id': 'key-005',
          'accountId': 'acc-005',
          'name': 'Null Used Quota',
          'quota': 300,
          'usedQuota': null,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.usedQuota, equals(0));
      });

      test('preserves non-zero usedQuota', () {
        final map = <String, dynamic>{
          'id': 'key-006',
          'accountId': 'acc-006',
          'name': 'Has Usage',
          'quota': 1000,
          'usedQuota': 750,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.usedQuota, equals(750));
      });

      test('handles null quota', () {
        final map = <String, dynamic>{
          'id': 'key-007',
          'accountId': 'acc-007',
          'name': 'Unlimited',
          'quota': null,
          'usedQuota': 10,
          'createdAt': fixedCreatedAt.toIso8601String(),
          'updatedAt': fixedUpdatedAt.toIso8601String(),
        };

        final apiKey = ApiKeyMapper.fromMap(map);

        expect(apiKey.quota, isNull);
      });
    });

    group('roundtrip', () {
      test(
        'toMap then fromMap preserves all fields including nullable ones',
        () {
          final original = createTestApiKey(expiresAt: fixedExpiresAt);
          final map = ApiKeyMapper.toMap(original);
          final restored = ApiKeyMapper.fromMap(map);

          expect(restored.id, equals(original.id));
          expect(restored.accountId, equals(original.accountId));
          expect(restored.name, equals(original.name));
          expect(restored.quota, equals(original.quota));
          expect(restored.usedQuota, equals(original.usedQuota));
          expect(restored.expiresAt, equals(original.expiresAt));
          expect(restored.createdAt, equals(original.createdAt));
          expect(restored.updatedAt, equals(original.updatedAt));
        },
      );

      test('toMap then fromMap preserves null expiresAt and null quota', () {
        final original = createTestApiKey(quota: null, expiresAt: null);
        final map = ApiKeyMapper.toMap(original);
        final restored = ApiKeyMapper.fromMap(map);

        expect(restored.quota, isNull);
        expect(restored.expiresAt, isNull);
        expect(restored.id, equals(original.id));
        expect(restored.accountId, equals(original.accountId));
        expect(restored.name, equals(original.name));
        expect(restored.usedQuota, equals(original.usedQuota));
      });
    });
  });
}
