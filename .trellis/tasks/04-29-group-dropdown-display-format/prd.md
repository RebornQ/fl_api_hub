# 分组下拉选择项显示格式：名称-描述（倍率：ratio值）

## Goal
修改分组选择下拉框的显示格式，从只显示名称改为显示"名称 - 描述（倍率：ratio值）"。

## Requirements
- 下拉选项显示格式：`名称 - 描述（倍率：ratio）`
- 描述为空时：`名称（倍率：ratio）`
- ratio 为空时：`名称 - 描述`（不显示倍率）
- 描述和 ratio 都为空时：只显示 `名称`

## Files to modify
- `lib/features/keys/presentation/widgets/key_form_sheet.dart`

## Current implementation
当前代码（第 194-218 行）只使用 `sortedNames`（名称列表）：
```dart
final uniqueNames = <String>{for (final g in groups) g.name};
final sortedNames = uniqueNames.toList()..sort();
...sortedNames.map((name) => DropdownMenuItem<String?>(
  value: name,
  child: Text(name),
)),
```

## Proposed implementation
改为保留完整的 `GroupDto` 对象，并创建显示文本辅助方法：
```dart
final uniqueGroups = <String, GroupDto>{for (final g in groups) g.name: g};
final sortedGroups = uniqueGroups.values.toList()
  ..sort((a, b) => a.name.compareTo(b.name));
...sortedGroups.map((group) => DropdownMenuItem<String?>(
  value: group.name,
  child: Text(_formatGroupDisplay(group)),
)),
```

显示格式辅助方法：
```dart
String _formatGroupDisplay(GroupDto group) {
  final parts = <String>[group.name];
  if (group.description != null && group.description!.isNotEmpty) {
    parts.add(' - ${group.description}');
  }
  if (group.ratio != null) {
    parts.add('（倍率：${group.ratio!.toStringAsFixed(2)}）');
  }
  return parts.join();
}
```

## Acceptance Criteria
- [ ] 分组下拉显示包含名称、描述（如有）、倍率（如有）
- [ ] 格式正确：`名称 - 描述（倍率：ratio）` 或简化变体
- [ ] value 仍为 group.name（用于 API 写入）
- [ ] `flutter analyze` 无新增 warning