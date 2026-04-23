import 'package:flutter_test/flutter_test.dart';

import 'package:fl_all_api_hub/features/tags/data/models/tag_mapper.dart';
import 'package:fl_all_api_hub/features/tags/domain/entities/tag.dart';

void main() {
  group('Tag', () {
    final createdAt = DateTime(2026, 1, 1, 10);
    final updatedAt = DateTime(2026, 1, 2, 12);

    test('normalizedKey trims and lowercases', () {
      final tag = Tag(
        id: 't-1',
        name: '  Production  ',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(tag.normalizedKey, 'production');
    });

    test('copyWith replaces specified fields', () {
      final tag = Tag(
        id: 't-1',
        name: 'Prod',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final renamed = tag.copyWith(
        name: 'Production',
        updatedAt: DateTime(2026, 1, 3),
      );
      expect(renamed.id, 't-1');
      expect(renamed.name, 'Production');
      expect(renamed.createdAt, createdAt);
      expect(renamed.updatedAt, DateTime(2026, 1, 3));
    });

    test('equality is id-based', () {
      final a = Tag(
        id: 't-1',
        name: 'A',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final b = Tag(
        id: 't-1',
        name: 'B',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final c = Tag(
        id: 't-2',
        name: 'A',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('TagMapper', () {
    final createdAt = DateTime(2026, 1, 1, 10, 30, 0);
    final updatedAt = DateTime(2026, 1, 2, 11, 30, 0);

    test('roundtrip preserves fields', () {
      final tag = Tag(
        id: 't-1',
        name: 'Production',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      final restored = TagMapper.fromMap(TagMapper.toMap(tag));
      expect(restored.id, tag.id);
      expect(restored.name, tag.name);
      expect(restored.createdAt, tag.createdAt);
      expect(restored.updatedAt, tag.updatedAt);
    });
  });
}
