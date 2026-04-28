# S3: 账号搜索支持标签名匹配

## Goal

账号列表搜索时，关键词应能匹配账号关联的标签名。

## Current Behavior

`accounts_filter_providers.dart:104-114`:
```dart
final searched = query.isEmpty
    ? list
    : list.where((a) {
        if (a.name.toLowerCase().contains(query)) return true;
        if (a.baseUrl.toLowerCase().contains(query)) return true;
        final notes = a.notes;
        if (notes != null && notes.toLowerCase().contains(query)) return true;
        return false;
      }).toList();
```
仅搜索 `name`、`baseUrl`、`notes`，未匹配标签。

## Target Behavior

搜索同时匹配 `account.tagIds` 关联的 `Tag.name`（case-insensitive contains）。

## Implementation

1. 在 `filteredAccountsProvider` 中 watch `tagsProvider`
2. 构建 `tagIdToName` 映射（`Map<String, String>`）
3. 搜索逻辑增加：遍历 `account.tagIds`，检查映射的标签名是否包含 query

```dart
final tags = ref.watch(tagsProvider);
final tagIdToName = <String, String>{};
tags.whenData((list) {
  for (final tag in list) {
    tagIdToName[tag.id] = tag.name.toLowerCase();
  }
});

// In search filter:
for (final tagId in a.tagIds) {
  final tagName = tagIdToName[tagId];
  if (tagName != null && tagName.contains(query)) return true;
}
```

## Files

- `lib/features/accounts/presentation/providers/accounts_filter_providers.dart`
  - 增加 `tagsProvider` 导入
  - `filteredAccountsProvider` 中 watch tags + 构建映射
  - 搜索条件增加标签匹配

## Acceptance Criteria

- [ ] 搜索标签名能匹配到关联账号
- [ ] 现有搜索（name/baseUrl/notes）不受影响
- [ ] tagsProvider 加载中时搜索不报错（fallback 不匹配标签）

## Definition of Done

- Provider 单测覆盖标签搜索场景
- `flutter analyze` clean
