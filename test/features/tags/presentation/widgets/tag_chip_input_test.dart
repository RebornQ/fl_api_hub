import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/app/theme/app_theme.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/tags/domain/entities/tag.dart';
import 'package:all_api_hub_flutter/features/tags/domain/repositories/tags_repository.dart';
import 'package:all_api_hub_flutter/features/tags/presentation/providers/tags_providers.dart';
import 'package:all_api_hub_flutter/features/tags/presentation/widgets/tag_chip_input.dart';

class MockTagsRepository extends Mock implements TagsRepository {}

Tag _tag(String id, String name) => Tag(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  late MockTagsRepository repo;

  setUp(() {
    repo = MockTagsRepository();
  });

  Widget harness({
    required List<String> initialSelected,
    required ValueChanged<List<String>> onChanged,
  }) {
    return ProviderScope(
      overrides: [tagsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TagChipInput(
              selectedTagIds: initialSelected,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders selected chips and the add chip', (tester) async {
    when(() => repo.getAll()).thenAnswer(
      (_) async => Success([_tag('t-1', 'Prod'), _tag('t-2', 'Staging')]),
    );

    await tester.pumpWidget(
      harness(initialSelected: ['t-1'], onChanged: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tagChip-t-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagChip-t-2')), findsNothing);
    expect(find.byKey(const ValueKey('tagAddChip')), findsOneWidget);
    expect(find.text('Prod'), findsOneWidget);
  });

  testWidgets('delete icon on chip removes tagId from selection', (
    tester,
  ) async {
    when(
      () => repo.getAll(),
    ).thenAnswer((_) async => Success([_tag('t-1', 'Prod')]));
    var latest = ['t-1'];

    await tester.pumpWidget(
      harness(initialSelected: latest, onChanged: (next) => latest = next),
    );
    await tester.pumpAndSettle();

    // InputChip's delete icon is a Material icon named cancel.
    final deleteIcon = find.descendant(
      of: find.byKey(const ValueKey('tagChip-t-1')),
      matching: find.byType(InkWell),
    );
    expect(deleteIcon, findsWidgets);
    await tester.tap(deleteIcon.last);
    await tester.pump();

    expect(latest, isEmpty);
  });

  testWidgets('add chip opens picker listing existing tags', (tester) async {
    when(() => repo.getAll()).thenAnswer(
      (_) async => Success([_tag('t-1', 'Prod'), _tag('t-2', 'Staging')]),
    );

    await tester.pumpWidget(harness(initialSelected: [], onChanged: (_) {}));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tagAddChip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tagOption-t-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tagOption-t-2')), findsOneWidget);
  });

  testWidgets('picker can create a new tag and returns it on confirm', (
    tester,
  ) async {
    when(() => repo.getAll()).thenAnswer((_) async => const Success([]));
    when(
      () => repo.upsertByName('New Tag'),
    ).thenAnswer((_) async => Success(_tag('t-new', 'New Tag')));

    List<String>? latest;
    await tester.pumpWidget(
      harness(initialSelected: const [], onChanged: (next) => latest = next),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tagAddChip')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tagPickerSearch')),
      'New Tag',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tagPickerCreate')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tagPickerCreate')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tagPickerConfirm')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest, contains('t-new'));
    verify(() => repo.upsertByName('New Tag')).called(1);
  });
}
