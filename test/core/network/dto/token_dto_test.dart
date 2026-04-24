import 'package:flutter_test/flutter_test.dart';
import 'package:fl_api_hub/core/network/dto/token_dto.dart';

void main() {
  group('TokenDto', () {
    test('all fields parsed correctly', () {
      final json = {
        'id': 42,
        'name': 'my-token',
        'key': 'sk-abc123',
        'quota': 5000,
        'used_quota': 1000,
        'status': 1,
        'created_time': 1700000000,
        'accessed_time': 1700100000,
        'expired_time': 1800000000,
      };
      final dto = TokenDto.fromJson(json);
      expect(dto.id, '42');
      expect(dto.name, 'my-token');
      expect(dto.key, 'sk-abc123');
      expect(dto.quota, 5000);
      expect(dto.usedQuota, 1000);
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

    test('isKeyMasked returns true for masked key with asterisks', () {
      final dto = TokenDto.fromJson({'key': 'sk-***abc'});
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
