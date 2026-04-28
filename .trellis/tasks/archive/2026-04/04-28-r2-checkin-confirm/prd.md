# R2: 右滑签到二次确认

## Goal

账号列表右滑手动签到时弹出确认对话框，避免误触。

## Requirements

- 右滑签到 → 弹出确认对话框：「确定要为「{name}」执行签到吗？」
- 按钮：「取消」+「确认签到」
- 取消 → 卡片弹回，不执行签到
- 确认 → 执行签到流程不变
- 删除滑动行为不变

## Modified Files

- `lib/features/accounts/presentation/pages/accounts_page.dart`
  - `confirmDismiss` 的 `startToEnd` 分支改为弹出确认对话框
  - 新增 `_confirmCheckIn` 方法

## Implementation

```dart
confirmDismiss: (direction) async {
  if (direction == DismissDirection.startToEnd) {
    return _confirmCheckIn(context, account);
  }
  return _confirmDelete(context, ref, account);
},
```

`_confirmCheckIn` 返回 `bool?`，确认后调用 `_performCheckIn` 并返回 `false`（不 dismiss 卡片）。
