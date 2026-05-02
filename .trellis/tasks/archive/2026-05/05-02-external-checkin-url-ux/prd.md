# feat: 外部签到 URL 模式 — 账号列表 UX 调整

## Goal

当账号的 `customCheckInUrl` 非空且 `autoCheckInEnabled=true` 时，将账号列表项的签到相关 UI 从「API 签到」切换为「外部签到」模式，引导用户跳转外部网页完成签到。

## What I already know

**现有实现**:
- `AccountCard`（`account_card.dart`）：`_resolveCheckInIcon()` 根据 `autoCheckInEnabled` + API 状态渲染签到图标（绿勾/红叉）
- `accounts_page.dart`：长按弹出 PopupMenu 含「签到」选项（条件：`!isDisabled && autoCheckInEnabled`）
- `accounts_page.dart`：`Dismissible` 右划签到仅在 `autoCheckInEnabled=true` 时启用
- `CheckInConfig`（`check_in_config.dart`）：`customCheckInUrl` 字段已存在，为外部签到页面 URL
- 浏览器服务（`browser_service.dart`）：已有 `openUrlInBrowser()` 统一入口，支持内置/系统浏览器切换

**条件判断**：
- 定义 `hasExternalCheckIn = autoCheckInEnabled && customCheckInUrl != null && customCheckInUrl!.isNotEmpty`

## Requirements

### R1: PopupMenu 菜单项替换

当 `hasExternalCheckIn == true` 时：
- **隐藏**「签到」选项（`value: 'check_in'`）
- **新增**「外部签到」选项（`value: 'external_check_in'`），图标 `Icons.language`，点击调用 `openUrlInBrowser()` 打开 `customCheckInUrl`
- 使用 `useInAppBrowserProvider` 决定浏览器类型，与现有「访问站点」行为一致

当 `hasExternalCheckIn == false` 时（`customCheckInUrl` 为空）：
- 保持现有行为不变（显示「签到」选项）

### R2: 禁用右划签到

当 `hasExternalCheckIn == true` 时：
- `Dismissible.direction` 设为 `DismissDirection.endToStart`（仅允许左滑删除）
- 禁止右划签到（因为需跳转外部页面，无法通过 API 完成签到）

当 `hasExternalCheckIn == false` 时：
- 保持现有行为不变

### R3: AccountCard 签到图标替换

当 `hasExternalCheckIn == true` 时：
- **隐藏**现有签到状态图标（绿勾/红叉）
- **新增** `Icons.web_outlined`（size: 14, color: `colorScheme.onSurfaceVariant`），表示已开启「外部签到」模式

当 `hasExternalCheckIn == false` 时：
- 保持现有 `_resolveCheckInIcon()` 行为不变

## R4: 签到 URL / 兑换 URL 校验

在 `CheckInConfigSection` 中为签到 URL 和兑换 URL 添加表单校验：
- 将 `TextField` 替换为 `TextFormField`，使其参与 Form 校验
- 校验规则：字段可选（空值允许），但如果填写了内容，必须以 `http://` 或 `https://` 开头
- 与站点 URL 的 `_validateUrl` 校验逻辑一致，但不要求必填
- 提示语：「请输入有效的 URL（以 http:// 或 https:// 开头）」

## Acceptance Criteria

- [ ] `customCheckInUrl` 非空且 `autoCheckInEnabled=true` 时，长按菜单显示「外部签到」而非「签到」
- [ ] 点击「外部签到」使用浏览器打开 `customCheckInUrl`（遵循内置/系统浏览器设置）
- [ ] `customCheckInUrl` 非空时，右划签到被禁用，仅保留左滑删除
- [ ] `customCheckInUrl` 非空且 `autoCheckInEnabled=true` 时，卡片显示 `Icons.web_outlined`（灰色）替代签到状态图标
- [ ] `customCheckInUrl` 为空时，所有行为与修改前一致
- [ ] 签到 URL 和兑换 URL 输入非法格式时显示校验错误提示
- [ ] `flutter analyze` 无错误

## Definition of Done

- Lint / typecheck green
- 代码格式化通过 `dart format .`
- 菜单交互反馈与现有操作一致（浏览器打开）

## Out of Scope

- 修改 `CheckInConfig` 数据结构
- 自动跳转/定时打开外部签到页面
- 宽屏布局的额外处理（现有长按逻辑已覆盖宽屏）

## Technical Notes

### 涉及文件

| 文件 | 修改要点 |
|------|----------|
| `lib/features/accounts/presentation/widgets/account_card.dart` | 修改 `_resolveCheckInIcon()` 增加 `customCheckInUrl` 参数，外部签到模式下返回 `(Icons.web_outlined, onSurfaceVariant)` |
| `lib/features/accounts/presentation/pages/accounts_page.dart` | 修改 `_showAccountContextMenu()` 菜单项条件、新增 `_handleContextMenuAction` case、修改 `Dismissible.direction` 条件 |
| `lib/features/accounts/presentation/widgets/check_in_config_section.dart` | 将签到 URL 和兑换 URL 的 `TextField` 替换为 `TextFormField`，添加可选 URL 格式校验 |

### 实现方案

**`_resolveCheckInIcon` 扩展**：

```dart
({IconData icon, Color color})? _resolveCheckInIcon({
  required bool autoCheckInEnabled,
  required bool? apiCheckInStatusToday,
  String? customCheckInUrl, // 新增参数
}) {
  if (!autoCheckInEnabled) return null;

  // External check-in mode: show web icon instead of status.
  if (customCheckInUrl != null && customCheckInUrl.isNotEmpty) {
    return (icon: Icons.web_outlined, color: colorScheme.onSurfaceVariant);
  }

  // ... existing logic
}
```

**PopupMenu 条件修改**：

```dart
// 替换原有的 check_in 条件
if (!isDisabled && account.checkIn.autoCheckInEnabled)
  if (hasExternalCheckIn)
    PopupMenuItem(value: 'external_check_in', ...)
  else
    PopupMenuItem(value: 'check_in', ...)
```

**Dismissible direction 修改**：

```dart
direction: (account.checkIn.autoCheckInEnabled &&
            (account.checkIn.customCheckInUrl == null ||
             account.checkIn.customCheckInUrl!.isEmpty))
    ? DismissDirection.horizontal
    : DismissDirection.endToStart,
```
