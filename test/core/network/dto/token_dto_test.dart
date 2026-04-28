import 'package:flutter_test/flutter_test.dart';
import 'package:fl_api_hub/core/network/dto/token_dto.dart';

void main() {
  group('TokenDto', () {
    test('Common API fields parsed correctly', () {
      final json = {
        'id': 42,
        'name': 'my-token',
        'key': 'sk-abc123',
        'remain_quota': 5000,
        'used_quota': 1000,
        'unlimited_quota': false,
        'status': 1,
        'created_time': 1700000000,
        'accessed_time': 1700100000,
        'expired_time': 1800000000,
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.id, '42');
      expect(dto.name, 'my-token');
      expect(dto.key, 'sk-abc123');
      expect(dto.remainQuota, 5000);
      expect(dto.usedQuota, 1000);
      expect(dto.unlimitedQuota, isFalse);
      expect(dto.status, 1);
      expect(
        dto.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(
        dto.accessedAt,
        DateTime.fromMillisecondsSinceEpoch(1700100000 * 1000),
      );
      expect(
        dto.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000),
      );
    });

    test('Sub2API fields parsed with USD → internal unit conversion', () {
      final json = {
        'id': 1,
        'name': 'sub2api-key',
        'key': 'sk-xyz789',
        'quota': 10.0, // USD
        'quota_used': 2.5, // USD
        'status': 'active',
        'created_at': '2024-01-01T00:00:00.000',
        'expires_at': '2025-12-31T23:59:59.000',
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.id, '1');
      expect(dto.remainQuota, 5000000); // 10 USD × 500000
      expect(dto.usedQuota, 1250000); // 2.5 USD × 500000
      expect(dto.status, 1); // "active" → 1
    });

    test('Sub2API inactive status mapped to 0', () {
      final dto = TokenDto.fromJson({'status': 'inactive'});
      expect(dto.status, 0);
    });

    test('Sub2API quota_exhausted status mapped to 0', () {
      final dto = TokenDto.fromJson({'status': 'quota_exhausted'});
      expect(dto.status, 0);
    });

    test('unlimited_quota flag parsed', () {
      final dto = TokenDto.fromJson({'unlimited_quota': true});
      expect(dto.unlimitedQuota, isTrue);
    });

    test('integer timestamps are converted to DateTime', () {
      final json = {
        'created_time': 1700000000,
        'accessed_time': 1700100000,
        'expired_time': 1800000000,
      };
      final dto = TokenDto.fromJson(json);
      expect(
        dto.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(
        dto.accessedAt,
        DateTime.fromMillisecondsSinceEpoch(1700100000 * 1000),
      );
      expect(
        dto.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000),
      );
    });

    test('string timestamps are parsed', () {
      final json = {
        'created_time': '2024-01-15T10:30:00.000',
        'accessed_time': '2024-02-20T12:00:00.000',
        'expired_time': '2025-12-31T23:59:59.000',
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.createdAt, DateTime.parse('2024-01-15T10:30:00.000'));
      expect(dto.accessedAt, DateTime.parse('2024-02-20T12:00:00.000'));
      expect(dto.expiresAt, DateTime.parse('2025-12-31T23:59:59.000'));
    });

    test('expired_time -1 treated as never expires', () {
      final dto = TokenDto.fromJson({'expired_time': -1});
      expect(dto.expiresAt, isNull);
    });

    test('zero and negative timestamps produce null DateTime', () {
      final dto = TokenDto.fromJson({'created_time': 0, 'accessed_time': -1});
      expect(dto.createdAt, isNull);
      expect(dto.accessedAt, isNull);
    });

    test('isKeyMasked returns true for masked key with asterisks', () {
      final dto = TokenDto.fromJson({'key': 'sk-***abc'});
      expect(dto.isKeyMasked, isTrue);
    });

    test('isKeyMasked returns true for ellipsis mask', () {
      final dto = TokenDto.fromJson({'key': 'sk-abc…xyz'});
      expect(dto.isKeyMasked, isTrue);
    });

    test('isKeyMasked returns false for unmasked key', () {
      final dto = TokenDto.fromJson({'key': 'sk-abcdef123456'});
      expect(dto.isKeyMasked, isFalse);
    });

    test('isKeyMasked returns false when key is null', () {
      final dto = TokenDto.fromJson(<String, dynamic>{});
      expect(dto.isKeyMasked, isFalse);
    });

    test('id is coerced via toString', () {
      final dto = TokenDto.fromJson({'id': 123});
      expect(dto.id, '123');
    });

    test('Common remain_quota takes priority over Sub2API quota', () {
      final json = {'remain_quota': 5000, 'quota': 10.0};
      final dto = TokenDto.fromJson(json);
      expect(dto.remainQuota, 5000);
    });

    test('Common used_quota takes priority over Sub2API quota_used', () {
      final json = {'used_quota': 1000, 'quota_used': 2.5};
      final dto = TokenDto.fromJson(json);
      expect(dto.usedQuota, 1000);
    });

    test('Sub2API quota as string is parsed and converted', () {
      final json = {'quota': '10.5'};
      final dto = TokenDto.fromJson(json);
      expect(dto.remainQuota, (10.5 * 500000).round());
    });

    test('Sub2API quota_used as string is parsed and converted', () {
      final json = {'quota_used': '2.5'};
      final dto = TokenDto.fromJson(json);
      expect(dto.usedQuota, (2.5 * 500000).round());
    });

    test('Common remain_quota as string is parsed', () {
      final json = {'remain_quota': '5000'};
      final dto = TokenDto.fromJson(json);
      expect(dto.remainQuota, 5000);
    });

    test('invalid string quota returns null', () {
      final json = {'quota': 'not-a-number'};
      final dto = TokenDto.fromJson(json);
      expect(dto.remainQuota, isNull);
    });

    test('Common API group string field is parsed', () {
      final json = {'id': 1, 'name': 'token-a', 'group': 'premium'};
      final dto = TokenDto.fromJson(json);
      expect(dto.group, 'premium');
    });

    test('empty group string is treated as null', () {
      final json = {'id': 1, 'name': 'token-a', 'group': ''};
      final dto = TokenDto.fromJson(json);
      expect(dto.group, isNull);
    });

    test('Sub2API nested group object with name is parsed', () {
      final json = {
        'id': 1,
        'name': 'token-a',
        'group': {'id': 5, 'name': 'basic'},
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.group, 'basic');
    });

    test('Sub2API nested Group object (capital G) is parsed', () {
      final json = {
        'id': 1,
        'name': 'token-a',
        'Group': {'id': 5, 'name': 'enterprise'},
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.group, 'enterprise');
    });

    test('Sub2API nested group with empty name returns null', () {
      final json = {
        'id': 1,
        'name': 'token-a',
        'group': {'id': 5, 'name': ''},
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.group, isNull);
    });

    test('missing group field returns null', () {
      final json = {'id': 1, 'name': 'token-a'};
      final dto = TokenDto.fromJson(json);
      expect(dto.group, isNull);
    });
  });

  group('TokenListDto', () {
    test('parses items format', () {
      final json = {
        'items': [
          {'id': 1, 'name': 'token-a'},
          {'id': 2, 'name': 'token-b'},
        ],
        'total': 2,
      };
      final dto = TokenListDto.fromJson(json);
      expect(dto.tokens, hasLength(2));
      expect(dto.tokens[0].name, 'token-a');
      expect(dto.tokens[1].name, 'token-b');
      expect(dto.total, 2);
    });

    test('falls back to data format when items is absent', () {
      final json = {
        'data': [
          {'id': 10, 'name': 'token-x'},
        ],
        'total': 1,
      };
      final dto = TokenListDto.fromJson(json);
      expect(dto.tokens, hasLength(1));
      expect(dto.tokens[0].name, 'token-x');
      expect(dto.total, 1);
    });

    test('parses OneHub total_count field', () {
      final json = {
        'data': [
          {'id': 1, 'name': 'token-a'},
        ],
        'total_count': 42,
      };
      final dto = TokenListDto.fromJson(json);
      expect(dto.total, 42);
    });

    test('returns empty list when neither items nor data is present', () {
      final json = <String, dynamic>{};
      final dto = TokenListDto.fromJson(json);
      expect(dto.tokens, isEmpty);
    });

    test('total field is parsed', () {
      final json = {'items': <dynamic>[], 'total': 42};
      final dto = TokenListDto.fromJson(json);
      expect(dto.total, 42);
    });
  });
}
