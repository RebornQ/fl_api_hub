# S2: 密钥页账号选择器排序跟随账号列表

## Goal

密钥管理页面的账号选择器下拉列表排序应与账号列表页一致。

## Current Behavior

- `keys_page.dart:252` 传入 `accountsProvider` 原始列表
- `AccountSelector` 显示顺序为 Hive box 存储顺序
- 账号列表页通过 `filteredAccountsProvider` 按 sortOrder + enabled 分区排序

## Target Behavior

AccountSelector 中账号排序与账号列表一致：enabled 优先 + disabled 沉底，每组内按 sortOrder 升序。

## Implementation

在 `keys_page.dart` 中对 `list` 排序后再传入 `AccountSelector`：

```dart
data: (list) {
  final sorted = _sortAccounts(list);
  return AccountSelector(
    accounts: sorted,
    selectedId: _selectedAccountId,
    onChanged: (id) => setState(() {
      _selectedAccountId = id;
      _selectedKeyId = null;
    }),
  );
}

List<Account> _sortAccounts(List<Account> accounts) {
  final enabled = accounts.where((a) => a.enabled).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final disabled = accounts.where((a) => !a.enabled).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [...enabled, ...disabled];
}
```

## Files

- `lib/features/keys/presentation/pages/keys_page.dart`

## Acceptance Criteria

- [ ] AccountSelector 账号顺序与账号列表页一致
- [ ] 新增账号后下拉顺序自动更新

## Definition of Done

- `flutter analyze` clean
