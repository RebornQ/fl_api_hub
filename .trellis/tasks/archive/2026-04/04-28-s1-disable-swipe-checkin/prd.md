# S1: 禁止未开启自动签到的账号右划签到

## Goal

账号列表中，未开启自动签到的账号禁止右划手动签到，只保留左滑删除。

## Current Behavior

`accounts_page.dart:640-642`:
```dart
direction: account.enabled
    ? DismissDirection.horizontal
    : DismissDirection.endToStart,
```
- `enabled=true` → 可右划签到 + 左滑删除
- `enabled=false` → 只可左滑删除

## Target Behavior

- `checkIn.autoCheckInEnabled=true` → 可右划签到 + 左滑删除
- `checkIn.autoCheckInEnabled=false` → 只可左滑删除（无论 enabled 与否）

## Files

- `lib/features/accounts/presentation/pages/accounts_page.dart`
  - L640-642: 修改 `Dismissible.direction` 条件
  - L619-627 / L649-655: `background` 中的 `checkInBg` 条件化（仅 autoCheckIn 时显示）

## Acceptance Criteria

- [ ] `autoCheckInEnabled=true` 的账号右划可签到
- [ ] `autoCheckInEnabled=false` 的账号右划无响应
- [ ] 所有账号左滑删除行为不变

## Definition of Done

- 相关 widget 测试覆盖
- `flutter analyze` clean
