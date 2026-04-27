# fix: 删除密钥后选中状态置空

## Goal

修复删除密钥后 `_selectedKeyId` 未清除，导致导出工具栏显示异常数据的 bug。

## What I already know

- `_confirmDelete` (keys_page.dart L474-498) 删除成功后未设置 `_selectedKeyId = null`
- `KeyExportBar` (L172-188) 通过 `firstWhere(orElse: ...)` 查找选中密钥
- 删除后 `orElse` 创建空壳 `ApiKey(id: '', ...)` 传给导出栏
- 导出工具栏判断 `_selectedKeyId != null` 显示，拿到空壳数据显示异常

## Fix Strategy

在 `_confirmDelete` 成功删除后，`setState(() { _selectedKeyId = null; })`。

具体改动位置 keys_page.dart L496-498:
```dart
if (confirmed == true && _selectedAccountId != null) {
  ref.read(keysProvider(_selectedAccountId!).notifier).delete(apiKey.id);
  setState(() { _selectedKeyId = null; });  // 新增
}
```

## Acceptance Criteria

- [ ] 删除当前选中的密钥后，导出工具栏立即隐藏
- [ ] 删除非选中密钥后，选中状态不受影响

## Files

- `lib/features/keys/presentation/pages/keys_page.dart` — _confirmDelete 方法
