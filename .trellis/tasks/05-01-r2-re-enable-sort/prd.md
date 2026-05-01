# R2: 账号禁用后重新启用排序优化

## Goal

账号从禁用状态重新启用时，自动将排序位置设为所有启用账号的最后，避免排序错乱。

## Current Behavior

- `AccountsNotifier.toggleEnabled` 只切换 `enabled` 状态，不更新 `sortOrder`
- 禁用账号的 `sortOrder` 可能是旧值（如 0 或负数）
- 重新启用后，该账号可能排在其他启用账号的前面（因为 sortOrder 较小）

## Target Behavior

- 禁用账号重新启用时，`sortOrder` 设为当前所有启用账号的最大值 + 1
- 确保重新启用的账号排在启用列表的最后

## Acceptance Criteria

- [ ] 禁用账号重新启用后排在启用列表最后
- [ ] 禁用账号（保持禁用）不影响排序
- [ ] `flutter analyze` 无错误

## Technical Approach

**文件**：`lib/features/accounts/presentation/providers/accounts_notifier.dart`

修改 `toggleEnabled` 方法（约第 105-132 行）：

```dart
Future<void> toggleEnabled(String id) async {
  final current = state.valueOrNull;
  if (current == null) return;

  final account = current.firstWhere(
    (a) => a.id == id,
    orElse: () => throw StateError('Account $id not found in state'),
  );

  // Compute new sortOrder when enabling (disabled -> enabled)
  int newSortOrder = account.sortOrder;
  if (!account.enabled) {
    // Place at the end of enabled accounts
    final enabledAccounts = current.where((a) => a.enabled).toList();
    final maxSortOrder = enabledAccounts.fold<int>(
      -1,
      (max, a) => a.sortOrder > max ? a.sortOrder : max,
    );
    newSortOrder = maxSortOrder + 1;
  }

  final updated = account.copyWith(
    enabled: !account.enabled,
    sortOrder: newSortOrder,
    updatedAt: DateTime.now(),
  );

  state = const AsyncLoading();
  final repo = ref.read(accountsRepositoryProvider);
  final result = await repo.update(updated);
  switch (result) {
    case Success():
      final all = await repo.getAll();
      state = AsyncData(all.dataOrNull ?? []);
      if (!updated.enabled) {
        await ref.read(accountReachabilityMapProvider.notifier).remove(id);
      }
    case Failure(:final exception):
      state = AsyncError(exception, StackTrace.current);
  }
}
```

## Files

- `lib/features/accounts/presentation/providers/accounts_notifier.dart`

## Out of Scope

- 不修改账号列表的排序显示逻辑
- 不修改拖拽排序功能