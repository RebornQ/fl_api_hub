# feat: 账号列表长按弹出菜单

## Goal

在账号列表非编辑模式下，为列表项添加长按弹出 PopupMenu 功能，提供签到、刷新账号状态、访问站点链接、禁用/启用账号四个快捷操作入口。

## What I already know

**现有实现（accounts_page.dart）**:
- 非编辑模式下 `AccountCard` 只有 `onTap`，无 `onLongPress`
- 编辑模式已实现（拖拽排序 + 抖动动画），长按手势在非编辑模式下已解放
- `_performCheckIn()` 方法已有完整签到逻辑（fire-and-forget + SnackBar 反馈）
- `accountsProvider.notifier.toggleEnabled()` 已有启用/禁用切换
- `accountsProvider.notifier.checkOne()` 已有单账号可达性检查
- 宽屏（≥900px）有 master-detail 双列布局

**AccountCard 组件**:
- `ConsumerStatefulWidget`，有 `onTap` 回调
- 有 `isEditMode` 和 `isSelected` 参数
- 无 `onLongPress` 参数

**Account 实体**:
- `account.enabled` — 启用/禁用状态
- `account.checkIn.autoCheckInEnabled` — 自动签到开关
- `account.baseUrl` — 站点 URL

**浏览器服务**:
- `lib/core/browser/browser_service.dart` 已有通用浏览器打开逻辑

## Requirements

### R1: AccountCard 添加 onLongPress 回调

- `AccountCard` 新增 `onLongPress` 可选回调参数
- 非编辑模式下长按触发 `onLongPress`
- 编辑模式下长按不触发（由 `ReorderableDragStartListener` 处理拖拽）

### R2: PopupMenu 弹出菜单

- 非编辑模式下长按列表项，在按压位置弹出 `PopupMenuButton` 风格的紧凑菜单
- 使用 `showMenu()` 或自定义 `PopupMenu` 实现
- 菜单项带图标 + 文字

### R3: 菜单选项

| 选项 | 图标 | 条件 | 行为 |
|------|------|------|------|
| 签到 | `Icons.check_circle_outline` | 仅 `autoCheckInEnabled == true` | 复用 `_performCheckIn()` 逻辑 |
| 刷新状态 | `Icons.refresh` | 始终显示 | 调用 `checkOne(account.id)` 刷新单账号可达性 |
| 访问站点 | `Icons.open_in_new` | 始终显示 | 使用 `browser_service` 打开 `account.baseUrl` |
| 禁用/启用 | `Icons.toggle_on` / `Icons.toggle_off` | 始终显示，文字动态切换 | 调用 `toggleEnabled(account.id)` |

### R4: 宽屏兼容

- 宽屏（≥900px）master-detail 布局下同样支持长按弹出菜单
- 长按操作不影响宽屏的选中状态和键盘导航

## Acceptance Criteria

- [ ] 非编辑模式下长按账号卡片弹出 PopupMenu
- [ ] 编辑模式下长按不弹出菜单（保持拖拽行为）
- [ ] 「签到」选项仅对 `autoCheckInEnabled == true` 的账号显示
- [ ] 点击「签到」执行签到并显示 SnackBar 反馈
- [ ] 点击「刷新状态」触发单账号可达性检查
- [ ] 点击「访问站点」在浏览器中打开 `account.baseUrl`
- [ ] 「禁用/启用」选项文字根据当前 `enabled` 状态动态切换
- [ ] 点击「禁用/启用」切换状态并显示 SnackBar 反馈
- [ ] 宽屏布局下长按菜单正常工作
- [ ] `flutter analyze` 无错误

## Definition of Done

- Lint / typecheck / CI green
- 代码格式化通过 `dart format .`
- 菜单选项的交互反馈与现有操作一致（SnackBar 提示）

## Out of Scope

- 编辑模式下的长按行为改动（保持拖拽）
- 新增菜单选项（本次仅实现 4 个选项）
- 自定义 PopupMenu 样式（使用 Material Design 3 默认样式）

## Technical Notes

### 涉及文件

| 文件 | 修改要点 |
|------|----------|
| `lib/features/accounts/presentation/widgets/account_card.dart` | 新增 `onLongPress` 参数，在 `InkWell` 上设置 `onLongPress` |
| `lib/features/accounts/presentation/pages/accounts_page.dart` | 非编辑模式下传入 `onLongPress` 回调，实现 `_showContextMenu()` 方法 |
| `lib/features/accounts/presentation/providers/accounts_notifier.dart` | 可能需要复用 `checkOne()` 方法 |

### 实现方案

**PopupMenu 触发方式**：

在 `accounts_page.dart` 中实现 `_showContextMenu()` 方法：

```dart
void _showContextMenu(BuildContext context, Offset position, Account account) {
  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx, position.dy, 
      position.dx + 1, position.dy + 1,
    ),
    items: [
      // 条件性添加签到项
      if (account.checkIn.autoCheckInEnabled)
        PopupMenuItem(value: 'check_in', child: ...),
      // 始终显示的项
      PopupMenuItem(value: 'refresh', child: ...),
      PopupMenuItem(value: 'visit', child: ...),
      PopupMenuItem(value: 'toggle', child: ...),
    ],
  ).then((value) {
    if (value == null) return;
    _handleContextMenuAction(value, account);
  });
}
```

**获取按压位置**：

在 `AccountCard` 的 `InkWell.onLongPress` 中通过 `Builder` 获取 `RenderBox` 位置，或者直接使用 `GestureDetector` 获取 `LongPressStartDetails.position`。

推荐方案：使用 `GestureDetector` 包裹 `InkWell`，`onLongPressStart` 回调提供精确的按压坐标。

**宽屏布局**：长按菜单在宽屏 master-detail 布局下正常弹出，不影响选中状态（菜单操作完成后不改变 `selectedAccountIdProvider`，除非用户点击了卡片本身）。
