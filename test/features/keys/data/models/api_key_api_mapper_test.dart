import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/dto/token_dto.dart';
import 'package:fl_api_hub/features/keys/data/models/api_key_api_mapper.dart';
import 'package:fl_api_hub/features/keys/domain/entities/api_key.dart';

void main() {
  group('ApiKeyApiMapper', () {
    const testAccountId = 'account-id-1';

    test('toEntity maps all fields from a fully populated TokenDto', () {
      final createdAt = DateTime(2026, 3, 15, 10, 30);
      final expiresAt = DateTime(2027, 3, 15);
      final dto = TokenDto(
        id: 'token-42',
        name: 'My API Key',
        key: 'sk-abc123',
        remainQuota: 5000,
        usedQuota: 1200,
        unlimitedQuota: false,
        status: 1,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

      final result = ApiKeyApiMapper.toEntity(dto, accountId: testAccountId);

      expect(result, isA<ApiKey>());
      expect(result.id, 'token-42');
      expect(result.accountId, testAccountId);
      expect(result.name, 'My API Key');
      expect(result.quota, 5000);
      expect(result.usedQuota, 1200);
      expect(result.expiresAt, expiresAt);
      expect(result.createdAt, createdAt);
    });

    test('toEntity maps unlimited quota (remainQuota=null) to quota=null', () {
      final dto = TokenDto(
        id: 'token-99',
        name: 'Unlimited Key',
        remainQuota: 100,
        unlimitedQuota: true,
      );

      final result = ApiKeyApiMapper.toEntity(dto, accountId: testAccountId);

      // unlimitedQuota=true → quota=null regardless of remainQuota value.
      expect(result.quota, isNull);
    });

    test('toEntity uses defaults for null fields', () {
      final dto = TokenDto();

      final result = ApiKeyApiMapper.toEntity(dto, accountId: testAccountId);

      expect(result.id, '');
      expect(result.accountId, testAccountId);
      expect(result.name, 'Unnamed');
      expect(result.usedQuota, 0);
      expect(result.quota, isNull);
      expect(result.expiresAt, isNull);
      // createdAt falls back to DateTime.now() - just verify it is not null
      expect(result.createdAt, isNotNull);
    });

    test('toEntityList converts multiple DTOs', () {
      final dto1 = TokenDto(
        id: 'id-1',
        name: 'Key One',
        remainQuota: 100,
        usedQuota: 10,
        createdAt: DateTime(2026, 1, 1),
      );
      final dto2 = TokenDto(
        id: 'id-2',
        name: 'Key Two',
        remainQuota: 200,
        usedQuota: 20,
        createdAt: DateTime(2026, 2, 1),
      );

      final results = ApiKeyApiMapper.toEntityList([
        dto1,
        dto2,
      ], accountId: testAccountId);

      expect(results, hasLength(2));
      expect(results[0].id, 'id-1');
      expect(results[0].name, 'Key One');
      expect(results[0].quota, 100);
      expect(results[1].id, 'id-2');
      expect(results[1].name, 'Key Two');
      expect(results[1].quota, 200);
    });

    test('toEntityList with empty list returns empty list', () {
      final results = ApiKeyApiMapper.toEntityList(
        [],
        accountId: testAccountId,
      );

      expect(results, isEmpty);
      expect(results, isA<List<ApiKey>>());
    });
  });
}
