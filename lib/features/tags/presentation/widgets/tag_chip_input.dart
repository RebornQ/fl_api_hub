/// Chip-based tag selector used by account edit forms.
///
/// Reads the global [tagsProvider] so selected tags can be rendered as
/// [InputChip] widgets with their display names, and provides a "+ 添加
/// 标签" affordance that opens a bottom-sheet picker for selecting
/// existing tags or creating new ones on-the-fly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/tag.dart';
import '../providers/tags_providers.dart';

/// Inline chip-based tag selector.
class TagChipInput extends ConsumerWidget {
  /// Currently selected tag ids.
  final List<String> selectedTagIds;

  /// Called whenever the selection changes (add / remove / create).
  final ValueChanged<List<String>> onChanged;

  const TagChipInput({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTags = ref.watch(tagsProvider);
    final theme = Theme.of(context);

    return asyncTags.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        '加载标签失败：$e',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
      data: (allTags) {
        final tagById = {for (final t in allTags) t.id: t};
        final selectedTags = selectedTagIds
            .map((id) => tagById[id])
            .whereType<Tag>()
            .toList(growable: false);

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...selectedTags.map(
              (tag) => InputChip(
                key: ValueKey('tagChip-${tag.id}'),
                label: Text(tag.name),
                onDeleted: () {
                  final next = selectedTagIds
                      .where((id) => id != tag.id)
                      .toList(growable: false);
                  onChanged(next);
                },
              ),
            ),
            ActionChip(
              key: const ValueKey('tagAddChip'),
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('添加标签'),
              onPressed: () => _openPicker(context, ref, allTags),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    List<Tag> allTags,
  ) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) =>
          _TagPickerSheet(allTags: allTags, initiallySelected: selectedTagIds),
    );
    if (result != null) onChanged(result);
  }
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  final List<Tag> allTags;
  final List<String> initiallySelected;

  const _TagPickerSheet({
    required this.allTags,
    required this.initiallySelected,
  });

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final TextEditingController _searchController;
  late Set<String> _selected;
  bool _creating = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selected = widget.initiallySelected.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final trimmedQuery = _query.trim();
    final normalizedQuery = trimmedQuery.toLowerCase();
    final filtered = trimmedQuery.isEmpty
        ? widget.allTags
        : widget.allTags
              .where((t) => t.normalizedKey.contains(normalizedQuery))
              .toList(growable: false);
    final canCreate =
        trimmedQuery.isNotEmpty &&
        !widget.allTags.any((t) => t.normalizedKey == normalizedQuery);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('选择或创建标签', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('tagPickerSearch'),
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: '搜索或输入新标签名',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (filtered.isEmpty && !canCreate)
                    Text(
                      '还没有标签，输入名字创建一个吧～',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ...filtered.map(
                    (tag) => FilterChip(
                      key: ValueKey('tagOption-${tag.id}'),
                      label: Text(tag.name),
                      selected: _selected.contains(tag.id),
                      onSelected: (checked) {
                        setState(() {
                          if (checked) {
                            _selected.add(tag.id);
                          } else {
                            _selected.remove(tag.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canCreate) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey('tagPickerCreate'),
              icon: _creating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text('创建"$trimmedQuery"'),
              onPressed: _creating ? null : () => _create(trimmedQuery),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const ValueKey('tagPickerConfirm'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_selected.toList(growable: false)),
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _create(String rawName) async {
    setState(() => _creating = true);
    try {
      final tag = await ref.read(tagsProvider.notifier).upsertByName(rawName);
      if (!mounted) return;
      setState(() {
        _selected.add(tag.id);
        _searchController.clear();
        _query = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建标签失败：$e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
