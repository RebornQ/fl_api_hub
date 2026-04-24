# Journal - Reborn (Part 2)

> Continuation from `journal-1.md` (archived at ~2000 lines)
> Started: 2026-04-23

---



## Session 25: Fix check-in already-checked-in handling

**Date**: 2026-04-23
**Task**: Fix check-in already-checked-in handling
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 问题描述

New-API 签到接口存在两个问题：
1. "已签到"场景显示为失败 - New-API 返回 `success: false` 导致被错误处理为 Failure
2. "已签到"计入跳过计数 - 应该计入成功计数

## 解决方案

### 1. Adapter 层重写 checkIn 方法
- `CommonApiAdapter.checkIn` 和 `VeloeraApiAdapter.checkIn` 不再使用 `performRequest`
- 直接解析 `CheckInResultDto`，只要 HTTP 200 就返回 Success
- 委托 `CheckInApiMapper` 判断实际状态

### 2. DTO 结构重构
- 新增 `CheckInDataDto` 用于嵌套数据（checkin_date, quota_awarded）
- 重构 `CheckInResultDto` 匹配 New-API 响应结构（success + message + data）

### 3. 状态扩展
- 新增 `CheckInStatus.alreadyChecked` 枚举值
- 更新 `CheckInApiMapper.inferStatus()` 状态推断逻辑
- UI 显示紫色"已签到"徽章

### 4. 统计修复
- `AccountCheckInStats` 将 `alreadyChecked` 计入成功计数

## 状态映射

| 条件 | 状态 | UI 显示 | 统计计数 |
|------|------|---------|----------|
| success=true | success | 绿色"成功" | Success |
| success=false + "已签到" | alreadyChecked | 紫色"已签到" | Success |
| success=false + 其他 | failed | 红色"失败" | Failed |
| 账号禁用/无userId | skipped | 紫色"已跳过" | Skipped |

## 修改文件

**新增文件（3）：**
- `lib/core/network/dto/check_in_data_dto.dart` - 嵌套 DTO
- `test/core/network/adapters/common_api_adapter_test.dart` - Adapter 测试
- `input/specs/New-API 的签到响应处理.md` - 问题规格文档

**修改文件（14）：**
- `lib/core/network/adapters/common_api_adapter.dart` - 重写 checkIn
- `lib/core/network/adapters/veloera_api_adapter.dart` - 重写 checkIn
- `lib/core/network/dto/check_in_result_dto.dart` - 重构结构
- `lib/features/check_in/data/models/check_in_api_mapper.dart` - 更新状态推断
- `lib/features/check_in/domain/entities/check_in_result.dart` - 新增字段和枚举
- `lib/features/check_in/presentation/providers/account_check_in_history_notifier.dart` - 修复统计
- `lib/features/check_in/presentation/widgets/check_in_result_card.dart` - 支持新状态
- `lib/features/check_in/presentation/widgets/check_in_status_badge.dart` - 支持新状态
- `test/core/network/dto/check_in_result_dto_test.dart` - 更新测试
- `test/features/check_in/data/models/check_in_api_mapper_test.dart` - 更新测试
- `test/core/network/adapters/veloera_api_adapter_test.dart` - 更新测试
- `test/features/check_in/presentation/providers/check_in_notifier_userid_test.dart` - 修复测试
- `.trellis/spec/backend/directory-structure.md` - 文档化特殊处理

## 测试结果

- ✅ 26/26 测试通过
- ✅ 静态分析无错误
- ✅ 代码格式化完成

## 文档更新

在 `.trellis/spec/backend/directory-structure.md` 新增专门章节：
- 问题描述（为什么需要特殊处理）
- 解决方案（如何实现）
- 状态映射表（完整的映射规则）
- 实现细节（代码示例）
- 测试说明（测试场景）


### Git Commits

| Hash | Message |
|------|---------|
| `71068c0` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 26: fix(check-in): count alreadyChecked as success + fix data serialization

**Date**: 2026-04-23
**Task**: fix(check-in): count alreadyChecked as success + fix data serialization
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Fix three regressions from commit 71068c0 which added `CheckInStatus.alreadyChecked`:

1. **alreadyChecked not counted as success on main page** — `CheckInDashboardStats.from`, filter bar counts, and `_executeAll` SnackBar only counted `CheckInStatus.success`, missing `alreadyChecked`. The fix was applied to the detail page's `AccountCheckInStats` but missed the main page entirely.

2. **checkinDate/quotaAwarded not persisted** — `CheckInResultMapper.toMap` and `fromMap` never serialized the new fields added in 71068c0, so they were always `null` after reload.

3. **Detail page records incomplete** — `ref.listen` in `CheckInDetailView` used `(_, _)` callback that fired on every state transition (including loading→data), resetting paginated history to page 1 unnecessarily. Changed to `(previous, next)` with `if (!next.hasValue) return` guard.

| Area | Fix |
|------|-----|
| Main page stats | `alreadyChecked` counted as success in `CheckInDashboardStats.from` |
| Filter bar | `alreadyChecked` included in success count |
| ExecuteAll SnackBar | `alreadyChecked` included in success count |
| Data persistence | `checkinDate` + `quotaAwarded` added to mapper `toMap`/`fromMap` |
| Detail view | `ref.listen` skips loading transitions to prevent pagination reset |

**Updated Files**:
- `lib/features/check_in/presentation/providers/check_in_providers.dart`
- `lib/features/check_in/presentation/pages/check_in_page.dart`
- `lib/features/check_in/data/models/check_in_mapper.dart`
- `lib/features/check_in/presentation/widgets/check_in_detail_view.dart`

**Tests**:
- `test/features/check_in/domain/entities/check_in_result_test.dart` — enum length 3→4 + `alreadyChecked` parse test
- 460/460 all green, `dart analyze` clean


### Git Commits

| Hash | Message |
|------|---------|
| `7551856` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 27: Fix narrow-screen check-in detail page stale data

**Date**: 2026-04-23
**Task**: Fix narrow-screen check-in detail page stale data
**Branch**: `main`

### Summary

Fixed narrow-screen check-in detail page not refreshing after executeAll(). Root cause: ref.listen in CheckInDetailView only fires while mounted; on narrow screens the page is pushed after latestResultPerAccountProvider already settled. Fix: invalidate accountCheckInHistoryProvider and accountCheckInStatsProvider before Navigator.push in _openDetail.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `6ba6c74` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 28: Project rename: all_api_hub_flutter -> fl_all_api_hub

**Date**: 2026-04-23
**Task**: Project rename: all_api_hub_flutter -> fl_all_api_hub
**Branch**: `main`

### Summary

Renamed project across all platforms: Dart package name, application ID, display name, bundle identifiers, and Android MainActivity package path.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `4b6c01f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 29: Rename macOS app bundle to Fl All API Hub

**Date**: 2026-04-23
**Task**: Rename macOS app bundle to Fl All API Hub
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| 变更 | 说明 |
|------|------|
| PRODUCT_NAME | `fl_all_api_hub` → `Fl All API Hub` |

**修改文件**:
- `macos/Runner/Configs/AppInfo.xcconfig`


### Git Commits

| Hash | Message |
|------|---------|
| `efba8cb` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 30: 账号列表宽屏 Master-Detail 布局

**Date**: 2026-04-23
**Task**: 账号列表宽屏 Master-Detail 布局
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

为账号管理页面添加 900px 断点的响应式 master-detail 宽屏布局，并实现键盘方向键导航和 FAB 交互。

| Feature | Description |
|---------|-------------|
| 宽屏布局 | >= 900px 时左侧 40%（header + 搜索筛选 + 卡片列表）+ 右侧 60%（内联编辑表单） |
| AccountEditForm | 从 AccountEditPage 提取可复用编辑表单 widget，支持 dirtyNotifier / siteTypeNotifier |
| 选中效果 | AccountCard 新增 isSelected 参数，选中时 primaryContainer 背景加边框 |
| 键盘导航 | ArrowUp/ArrowDown 切换选中账号，Scrollable.ensureVisible 自动滚动到可视区 |
| FAB 切换 | 宽屏有改动时添加 FAB 隐藏、保存 FAB 出现；窄屏保存按钮改为 FAB |
| 未保存保护 | 切换账号/键盘导航时检测未保存编辑，弹确认对话框 |
| 选中持久化 | StateProvider 跨 Tab 保持选中状态，删除选中账号自动清空，ID 失效自动重置 |

**Modified Files**:
- `lib/features/accounts/presentation/providers/accounts_providers.dart` — 新增 selectedAccountIdProvider
- `lib/features/accounts/presentation/widgets/account_edit_form.dart` — **新建**，从 AccountEditPage 提取
- `lib/features/accounts/presentation/pages/account_edit_page.dart` — 重构为薄包装层 + 保存 FAB
- `lib/features/accounts/presentation/pages/accounts_page.dart` — LayoutBuilder 宽窄屏 + 键盘 + FAB
- `lib/features/accounts/presentation/widgets/account_card.dart` — 新增 isSelected 选中态
- `test/features/accounts/presentation/pages/account_edit_page_test.dart` — 适配 FAB + pump 时序
- `test/features/check_in/presentation/pages/check_in_page_test.dart` — 修复 selectedAccountIdProvider 命名冲突


### Git Commits

| Hash | Message |
|------|---------|
| `111b3e6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 31: 签到页 FAB 标准化改造

**Date**: 2026-04-23
**Task**: 签到页 FAB 标准化改造
**Branch**: `main`

### Summary

将签到页主 FAB 从自定义 Material+InkWell+Hero 包装替换为标准 FloatingActionButton，统一与账号页面风格。执行中状态改为 CircularProgressIndicator + onPressed: null 禁用。净减 13 行代码。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `bd6c37b` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 32: 账号刷新FAB + 保存后可达性检测

**Date**: 2026-04-23
**Task**: 账号刷新FAB + 保存后可达性检测
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| 改动 | 说明 |
|------|------|
| 搜索 FAB → 刷新 FAB | 替换空实现的搜索按钮为刷新按钮，触发 `checkAll(force: true)` |
| 旋转动画 | 点击后图标旋转，所有检测完成后停止 |
| 保存后可达性检测 | 放宽 `checkOne` 条件，任何已启用账号保存后都触发检测 |

**修改文件**:
- `lib/features/accounts/presentation/pages/accounts_page.dart` (+30/-11)
- `lib/features/accounts/presentation/widgets/account_edit_form.dart` (+4/-2)


### Git Commits

| Hash | Message |
|------|---------|
| `e73b1f5` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 33: 签到列表选中高亮 + 键盘导航

**Date**: 2026-04-23
**Task**: 签到列表选中高亮 + 键盘导航
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 改动内容

| 改动 | 说明 |
|------|------|
| CheckInResultCard | 添加 `isSelected` 属性，选中时 primaryContainer 背景 + 1.5px 边框 |
| 键盘导航 | 宽屏布局 Focus + ArrowUp/ArrowDown 切换账号详情 |
| 选中清除 | 过滤/搜索变更时自动清除选中状态 |
| 分割线通顶 | 将 header 移入宽屏 Row 左侧面板，VerticalDivider 全高 |
| 测试 | 新增 5 个 widget 测试（选中高亮、键盘导航、边界行为） |

**修改文件**:
- `lib/features/check_in/presentation/widgets/check_in_result_card.dart`
- `lib/features/check_in/presentation/pages/check_in_page.dart`
- `lib/features/check_in/presentation/widgets/check_in_filter_bar.dart`
- `test/features/check_in/presentation/pages/check_in_page_test.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `a8b4882` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 34: feat(accounts): add enable/disable toggle and check-in skip messages

**Date**: 2026-04-24
**Task**: feat(accounts): add enable/disable toggle and check-in skip messages
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

在账号编辑表单中添加启用/禁用开关，并在签到时为禁用账号和关闭自动签到的账号生成跳过记录。

## Changes

| Area | Description |
|------|-------------|
| Account Edit Form | 添加 `_enabled` 状态、UI 开关（站点信息顶部）、`_FormSnapshot` 支持 dirty 检测 |
| Check-in Notifier | 禁用账号 → "账号已禁用"；自动签到关闭 → "自动签到已关闭" |
| Sync Service | 为 autoCheckInEnabled=false 的账号创建 disabled 任务（确保所有账号都能产出结果） |
| Future.wait | 两处添加 `eagerError: false`，单个失败不再中断整个批次 |
| executeAll | 处理所有任务（不过滤 enabled），确保跳过消息覆盖所有账号 |

## Updated Files

- `lib/features/accounts/presentation/widgets/account_edit_form.dart`
- `lib/features/check_in/presentation/providers/check_in_notifier.dart`
- `lib/features/check_in/domain/services/account_check_in_sync_service.dart`
- `test/features/check_in/presentation/providers/check_in_notifier_test.dart`
- `test/features/check_in/presentation/providers/check_in_notifier_userid_test.dart`
- `test/features/check_in/domain/services/account_check_in_sync_service_test.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `87b7f23` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 35: fix(ui): badge colors and account form tweaks

**Date**: 2026-04-24
**Task**: fix(ui): badge colors and account form tweaks
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Change | Description |
|--------|-------------|
| Badge colors | alreadyChecked→green, skipped→yellow |
| Enable toggle | Moved above site info card, Row+Switch (no ripple) |
| Notes field | alignLabelWithHint + textAlignVertical top |
| Spec sync | Updated color mapping in directory-structure.md |

**Modified Files**:
- `lib/features/check_in/presentation/widgets/check_in_status_badge.dart`
- `lib/features/accounts/presentation/widgets/account_edit_form.dart`
- `.trellis/spec/backend/directory-structure.md`


### Git Commits

| Hash | Message |
|------|---------|
| `6d31dd2` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 36: 账号列表项签到状态图标

**Date**: 2026-04-24
**Task**: 账号列表项签到状态图标
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| 改动 | 说明 |
|------|------|
| 新增 Provider | `latestResultByAccountProvider` — 将签到结果列表转为 Map<accountId, result>，支持 O(1) 查询 |
| 修改 AccountCard | 转为 ConsumerWidget，账号名旁显示 14dp 签到状态图标 |
| 新增纯函数 | `_resolveCheckInIcon` — 根据自动签到开关和今日结果返回图标/颜色 |

**图标规则**：
- 未开启自动签到 → 不显示
- 今日 success/alreadyChecked → 绿色 check_circle
- 今日 failed → 橙色 error
- 无结果/非今日/skipped → 红色 cancel

**修改文件**：
- `lib/features/check_in/presentation/providers/check_in_providers.dart`
- `lib/features/accounts/presentation/widgets/account_card.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `5c3140f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 37: Generate app launcher icons for all platforms

**Date**: 2026-04-24
**Task**: Generate app launcher icons for all platforms
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Item | Description |
|------|-------------|
| Config | Created `icons_launcher.yaml` with platform-specific settings |
| Source Icons | `icons/icon-hub-1024-new.png` (enlarged, padding removed), `icons/icon-hub-1024-ios.png` (#D2D0E8 background composited) |
| Android | Adaptive icons with `#D2D0E8` background color + foreground image |
| iOS | Pre-composited #D2D0E8 background (icons_launcher hardcodes white for alpha removal) |
| macOS / Web / Windows / Linux | Generated from enlarged source icon |
| Tool Scripts | `tool/composite_ios_icon.dart`, `tool/remove_icon_padding.dart` |

**Key Decisions**:
- Original icon had ~27% padding per side (content only 46% of canvas) — cropped and enlarged to ~95%
- iOS uses separate pre-composited image because `icons_launcher` hardcodes `#FFFFFF` for alpha removal
- All source icons consolidated in `icons/` directory


### Git Commits

| Hash | Message |
|------|---------|
| `7ae3fa6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 38: 项目改名: Fl All API Hub → Fl API Hub

**Date**: 2026-04-24
**Task**: 项目改名: Fl All API Hub → Fl API Hub
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 变更范围

| 类别 | 旧值 | 新值 | 影响文件数 |
|------|------|------|-----------|
| App ID | com.mallotec.reb.flallapihub | com.mallotec.reb.flapihub | 6 平台配置 |
| 显示名 | Fl All API Hub | Fl API Hub | 8 平台文件 |
| pubspec name | fl_all_api_hub | fl_api_hub | 1 + 58 test imports |
| AppBar | API HUB | Fl API HUB | 1 |
| 二进制名 | fl_all_api_hub | fl_api_hub | Linux/Windows/Snap |
| macOS 产物 | fl_all_api_hub.app | Fl API Hub.app | pbxproj + xcscheme |

## 验证结果

- flutter analyze: No issues found
- dart format: 0 changed
- flutter test: 465/465 passed

## 修复的问题

- macOS pbxproj 中含空格的 path 值需要双引号包裹（Xcode 报错 Failed to load container）

## Trellis 任务

7 个任务全部归档（1 父任务 + 6 子任务）


### Git Commits

| Hash | Message |
|------|---------|
| `b4e2185` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 39: Fix app icons — scale content to safe zone

**Date**: 2026-04-24
**Task**: Fix app icons — scale content to safe zone
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 问题
源图 `icon-hub-1024-new.png` 的图标内容几乎填满整个 1024x1024 画布，导致 Android Adaptive Icon 的圆形/圆角遮罩裁掉边缘内容。

## 方案
- 用 Python Pillow 从源图提取内容，按不同平台规范缩放并生成专用源图
- 拆分为多平台专用源图：Android 前景（透明 66%）、通用图标（白底 75%）、macOS（白底圆角 75%）、iOS（白底 75%）、Google Play 512px

## 生成的新文件
| 文件 | 尺寸 | 背景 | 内容缩放 | 用途 |
|------|------|------|----------|------|
| `icons/icon-hub-1024-foreground.png` | 1024x1024 | 透明 | 66% | Android Adaptive Icon 前景层 |
| `icons/icon-hub-512-foreground.png` | 512x512 | 透明 | 66% | Android Adaptive Icon 前景层 (512) |
| `icons/icon-hub-1024-new-v2.png` | 1024x1024 | 白色 | 75% | 通用图标 (web/Windows/Linux) |
| `icons/icon-hub-1024-ios.png` | 1024x1024 | 白色 | 75% | iOS 图标 |
| `icons/icon-hub-1024-macOS.png` | 1024x1024 | 白色+圆角 | 75% | macOS 图标 |
| `icons/icon-hub-1024-play-512.png` | 512x512 | 白色 | 75% | Google Play 商店图标 |

## 修改的配置
- `icons_launcher.yaml` — Android adaptive foreground 改为专用前景图，macOS 改为圆角专用图

## 关键学习
- Android Adaptive Icon 安全区是内圈 66%，四周各留 17% 边距
- iOS/macOS 系统自动应用圆角遮罩，但 macOS 需要手动在源图中添加圆角
- Google Play 商店图标是 512x512 完整正方形，不加圆角（Play 动态添加）
- 不同平台需要不同的源图（透明前景 vs 带背景），不能一图通用


### Git Commits

| Hash | Message |
|------|---------|
| `7bbfff4` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 40: Desktop Window Management & macOS Settings Menu

**Date**: 2026-04-25
**Task**: Desktop Window Management & macOS Settings Menu
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Changes

| Feature | Description |
|---------|-------------|
| macOS Settings Menu | Wire Cmd+, and Settings menu item to navigate to Settings tab via MethodChannel → Riverpod StateProvider |
| Default Window Size | All desktop platforms: 80% of primary screen, minimum 1024×768 |
| Window Persistence (macOS) | Save/restore window size & position via UserDefaults; fullscreen state not persisted |
| Window Persistence (Windows) | Save/restore via Registry (HKEY_CURRENT_USER\Software\mallotec\flapihub) |
| Linux Window Sizing | Calculate 80% of workarea via gdk_monitor_get_workarea; no persistence |
| Riverpod Tab State | Tab index migrated from StatefulWidget local state to Riverpod StateProvider |
| MethodChannel Bridge | New `lib/core/platform/app_method_channel.dart` encapsulates native→Flutter communication |

**Files Modified**:
- `lib/core/platform/app_method_channel.dart` (new)
- `lib/app/router.dart` — added `tabIndexProvider` + `settingsTab` constant
- `lib/app/shell/app_shell.dart` — converted to ConsumerStatefulWidget
- `lib/app/app.dart` — removed ProviderScope (moved to main.dart)
- `lib/main.dart` — ProviderContainer + UncontrolledProviderScope
- `macos/Runner/MainFlutterWindow.swift` — window sizing + UserDefaults persistence
- `macos/Runner/AppDelegate.swift` — MethodChannel + programmatic Settings menu wiring
- `macos/Runner/Base.lproj/MainMenu.xib` — Preferences → Settings
- `linux/runner/my_application.cc` — 80% screen + min size constraints
- `windows/runner/main.cpp` — 80% + Registry read
- `windows/runner/flutter_window.cpp` / `.h` — WM_GETMINMAXINFO + WM_CLOSE save

## Key Decisions

- **Native-first window management**: All sizing/persistence done in platform-native code (Swift/C++/C), not Flutter plugins
- **Programmatic menu wiring**: Settings menu item wired at runtime in `applicationDidFinishLaunching` (before `super`) rather than XIB connections, which proved fragile
- **ProviderContainer at top level**: Created in `main()` so MethodChannel callback can directly access Riverpod state without widget tree traversal


### Git Commits

| Hash | Message |
|------|---------|
| `ab0110a` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 41: Add native splash screen for Android & iOS

**Date**: 2026-04-25
**Task**: Add native splash screen for Android & iOS
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Item | Detail |
|------|--------|
| Package | flutter_native_splash ^2.4.7 |
| Platforms | Android + iOS |
| Light mode | White bg + adaptive icon foreground logo + "Fl API Hub" branding |
| Dark mode | #1C1B1F bg + same logo + white branding text |
| Android 12+ | SplashScreen API with icon animation + branding |
| Init coord | FlutterNativeSplash.preserve() → await init → remove() |

**Files Created**:
- `flutter_native_splash.yaml` — splash config
- `icons/splash/` — 6 source images (logo + branding, light/dark, android12)
- `android/app/src/main/res/drawable-*/` — all density splash resources
- `android/app/src/main/res/values-v31/` — Android 12+ styles
- `ios/Runner/Assets.xcassets/BrandingImage.imageset/` — branding images
- `ios/Runner/Assets.xcassets/LaunchBackground.imageset/` — background images

**Files Modified**:
- `lib/main.dart` — added preserve/remove splash calls
- `pubspec.yaml` — added flutter_native_splash dependency
- `android/app/src/main/res/values*/styles.xml` — launch theme
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` — branded launch screen
- `ios/Runner/Info.plist` — status bar hidden during splash


### Git Commits

| Hash | Message |
|------|---------|
| `f158ff1` | (see git log) |
| `4d8054e` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 42: Dark theme + dynamic Monet color

**Date**: 2026-04-25
**Task**: Dark theme + dynamic Monet color
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Feature: Dark theme & dynamic Monet color

| Area | Description |
|------|-------------|
| Domain layer | `ThemePreference` entity with `AppThemeMode` enum (system/light/dark) + `dynamicColorEnabled` bool |
| Data layer | `ThemeLocalDataSource` (Hive `app_data` box) + `ThemeRepositoryImpl` |
| Presentation | `ThemeNotifier` (AsyncNotifier) + derived providers for `themeMode`, `dynamicColorEnabled`, `dynamicColorAvailable` |
| Theme | Refactored `AppTheme.buildFromScheme(ColorScheme)` + new `AppTheme.dark` getter |
| App entry | `ConsumerWidget` + `DynamicColorBuilder` wrapping `MaterialApp` with `themeMode`/`darkTheme` |
| Settings UI | `AppearanceSettings` — SegmentedButton (auto/light/dark) + Switch (dynamic color, hidden when platform unsupported) |
| Tests | Updated `widget_test.dart` with `UncontrolledProviderScope` wrapper |

**New files (7)**:
- `lib/features/settings/domain/entities/theme_preference.dart`
- `lib/features/settings/domain/repositories/theme_repository.dart`
- `lib/features/settings/data/datasources/theme_local_datasource.dart`
- `lib/features/settings/data/repositories/theme_repository_impl.dart`
- `lib/features/settings/presentation/providers/theme_notifier.dart`
- `lib/features/settings/presentation/providers/theme_providers.dart`
- `lib/features/settings/presentation/widgets/appearance_settings.dart`

**Modified files (4 + 1 test)**:
- `pubspec.yaml` — added `dynamic_color: ^1.7.0`
- `lib/app/theme/app_theme.dart` — `buildFromScheme` refactor + `dark`
- `lib/app/app.dart` — `ConsumerWidget` + `DynamicColorBuilder`
- `lib/features/settings/presentation/pages/settings_page.dart` — appearance section
- `test/widget_test.dart` — `ProviderScope` adaptation

**Key decisions**:
- Platform support auto-detected via `DynamicColorBuilder` callback; switch hidden when unavailable
- Defaults: system theme mode + dynamic color enabled
- Persistence: Hive `app_data` box (`theme_mode` / `dynamic_color_enabled` keys)


### Git Commits

| Hash | Message |
|------|---------|
| `f4034a6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
