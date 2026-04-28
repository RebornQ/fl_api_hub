# fix: UI polish — nav color, check-in confirm, key visibility

## Goal

三项独立的 UI 体验优化：底部导航栏选中色与 FAB 统一、右滑签到加二次确认、密钥脱敏前隐藏显示切换按钮。

## Requirements

### R1: 底部导航栏选中色与 FAB 统一

- `NavigationBar` 选中态（图标 + 文字 + indicator）使用 `colorScheme.primary`，与 FAB 的 `backgroundColor: colorScheme.primary` 保持一致
- 未选中态保持默认 `colorScheme.onSurfaceVariant`

**影响文件**: `lib/app/shell/app_shell.dart`

**实现方式**: 在 `NavigationBar` 上设置 `indicatorColor` 和通过 `NavigationDestinationLabelBehavior` / theme overlay 控制选中色

### R2: 右滑手动签到二次确认

- 账号列表右滑签到时弹出确认对话框，避免误触
- 对话框内容：「确定要为「{account.name}」执行签到吗？」
- 按钮：「取消」+「确认签到」
- 确认后执行签到，取消时卡片弹回（不做任何操作）

**影响文件**: `lib/features/accounts/presentation/pages/accounts_page.dart`

**实现方式**: 修改 `confirmDismiss` 回调中 `startToEnd` 方向的处理，增加 `showDialog` 确认

### R3: 密钥脱敏前隐藏显示/隐藏按钮

- 当密钥处于服务端脱敏状态（包含 `***` 或 `…`）时，隐藏 visibility toggle 按钮
- 脱敏状态下只显示 resolve（解析）按钮
- 解析成功后自动显示 visibility toggle
- 非脱敏状态保持原有行为不变

**影响文件**: `lib/features/keys/presentation/widgets/key_value_row.dart`

**实现方式**: 在 visibility toggle 的 `GestureDetector` 外增加 `_isServerMasked` 条件判断，脱敏时不渲染该按钮

## Acceptance Criteria

- [ ] NavigationBar 选中态颜色 = FAB 背景色（都是 `colorScheme.primary`）
- [ ] 右滑签到弹出确认对话框，取消后卡片弹回不执行签到
- [ ] 右滑签到确认后正常执行签到并显示结果 SnackBar
- [ ] 删除滑动不受影响，仍弹出删除确认框
- [ ] 服务端脱敏密钥（含 `***`/`…`）不显示 visibility toggle
- [ ] 解析成功后 visibility toggle 自动可见
- [ ] 非脱敏密钥 visibility toggle 正常显示和工作
- [ ] `flutter analyze` 无 warning
- [ ] 现有测试通过

## Definition of Done

- `flutter analyze` 无 warning
- `flutter test` 全部通过
- 三个子功能各自独立可验证

## Out of Scope

- NavigationBar 动画效果调整
- 签到结果展示方式变更
- 密钥解析逻辑变更

## Technical Notes

### R1 NavigationBar 选色

Flutter 3.x 的 `NavigationBar` 默认使用 `colorScheme.onSurface` 作为选中色。需要通过 `NavigationBarTheme` 或直接在 widget 上设置:
- `indicatorColor: colorScheme.primaryContainer` (indicator 背景)
- 选中 icon/label 颜色需要通过 theme 或 `selectedIcon` 的 color 属性控制

最简洁方式：在 `NavigationBar` 外层用 `NavigationBarTheme` 覆盖：
```dart
NavigationBarTheme(
  data: NavigationBarThemeData(
    indicatorColor: colorScheme.primaryContainer,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(color: colorScheme.primary);
      }
      return IconThemeData(color: colorScheme.onSurfaceVariant);
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600);
      }
      return TextStyle(color: colorScheme.onSurfaceVariant);
    }),
  ),
  child: NavigationBar(...),
)
```

### R2 确认对话框

在 `_buildAccountsList` 的 `Dismissible.confirmDismiss` 中，`startToEnd` 分支改为:
```dart
if (direction == DismissDirection.startToEnd) {
  return _confirmCheckIn(context, account);
}
```
新增 `_confirmCheckIn` 方法返回 `Future<bool?>`，确认后 `_performCheckIn`。

### R3 Visibility 条件

在 `key_value_row.dart` 第 99 行的 `GestureDetector` 外增加条件：
```dart
if (!_isServerMasked)
  GestureDetector(...visibility toggle...)
```
