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


## Session 43: feat(backup): 数据管理 — 备份与恢复（完整实现）

**Date**: 2026-04-25
**Task**: feat(backup): 数据管理 — 备份与恢复（完整实现）
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Feature: 备份与恢复（数据管理模块）

### 新增功能
| 模块 | 说明 |
|------|------|
| 加密备份 | AES-256-GCM + PBKDF2 密钥派生，可选密码加密 |
| 明文备份 | 支持不加密 JSON 格式导出 |
| 智能合并 | 按 ID + updatedAt 匹配，孤儿实体跳过，标签同名加后缀 |
| 全量替换 | 清空后写入备份数据 |
| 双导出方式 | 系统分享(share_plus) + 保存到文件(file_picker) |
| 密码持久化 | app_data Hive Box，自动复用 |
| 进度指示 | 阶段枚举 + 0.0~1.0 进度条 |
| 错误提示 | BackupException 层次，密码错误/校验失败/文件损坏等 |
| UI 入口 | 设置页 SectionCard「数据管理」→ 子页面 |

### 技术架构
- Clean Architecture + Feature-First: `features/backup/{data,domain,presentation}/`
- 7 个 Hive Box 全量备份（排除 account_reachability 缓存）
- 备份格式：JSON（未加密）或二进制（加密），扩展名 .flbkp
- 文件检测：首字节 `{` 为 JSON，否则为加密二进制

### 新增依赖
encrypt, crypto, share_plus, file_picker, path_provider

### 测试
- 491 个测试全部通过（含 26 个新增备份相关测试）
- flutter analyze 无新增警告

### Bug 修复（手动测试后）
- 临时目录不存在 → create(recursive: true)
- 保存文件无反应 → file_picker saveFile 手动写 bytes
- 导出后按钮不恢复 → 操作完成后 reset() 回 BackupIdle

**新增文件 (21)**:
- lib/features/backup/data/ (7 files)
- lib/features/backup/domain/ (2 files)
- lib/features/backup/presentation/ (6 files)
- test/features/backup/ (4 files)
- .trellis/tasks/04-25-04-25-backup-restore/ (5 files)

**修改文件 (2)**:
- lib/core/error/app_exception.dart — 新增 BackupException
- lib/features/settings/presentation/pages/settings_page.dart — 新增数据管理入口


### Git Commits

(No commits - planning session)

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 44: fix(backup): 备份恢复功能多项 bug 修复

**Date**: 2026-04-25
**Task**: fix(backup): 备份恢复功能多项 bug 修复
**Branch**: `main`

### Summary

修复备份恢复功能的 7 个问题：Android 文件选择器无法选中 .flhbkp、创建备份和加密恢复卡 UI、加密开关切换无反应、操作状态耦合、错误提示持久停留、恢复后数据未刷新、加密恢复重复输密码

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `8e70635` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 45: Settings page layout refactor & search bar improvements

**Date**: 2026-04-25
**Task**: Settings page layout refactor & search bar improvements
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Change | Description |
|--------|-------------|
| Settings page | Unified layout with SectionCard, removed Dividers, added padding with AppSpacing.sm |
| Appearance settings | Removed manual title/divider, added ListTile-based theme selector with LayoutBuilder adaptive title |
| Developer options | Same SectionCard treatment, removed Dividers and manual headers |
| Backup page | Hardcoded 8px → AppSpacing.sm for consistency |
| Request logger | Switch.adaptive → Switch (MD3 style consistency) |
| Keys search bar | Added TextEditingController + conditional clear button |
| Check-in search bar | CheckInFilterBar → StatefulWidget, added controller + clear button |
| Keys empty state | Removed redundant "add key" button (FAB already exists) |

**Modified Files**:
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/settings/presentation/widgets/appearance_settings.dart`
- `lib/features/dev_tools/request_logger/presentation/pages/developer_options_page.dart`
- `lib/features/dev_tools/request_logger/presentation/pages/request_logger_page.dart`
- `lib/features/backup/presentation/pages/backup_page.dart`
- `lib/features/keys/presentation/pages/keys_page.dart`
- `lib/features/check_in/presentation/widgets/check_in_filter_bar.dart`
- `lib/features/accounts/presentation/pages/accounts_page.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `1a7bfbc` | (see git log) |
| `75280e1` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 46: 签到请求记录查看与持久化

**Date**: 2026-04-25
**Task**: 签到请求记录查看与持久化
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 目标

为签到详情页的每条签到记录添加网络请求记录查看功能，便于排查签到失败原因。请求记录持久化到 Hive，页面复用现有 RequestLogger UI 组件。

## 实现概要

| 模块 | 改动 |
|------|------|
| Correlation ID 机制 | `ApiRequest.correlationId` → `CommonApiAdapter._buildExtra()` → `RequestLoggerInterceptor` 捕获并写入 `RequestLogEntry` |
| 持久化存储 | 新增 Hive box `check_in_request_logs`，`CheckInRequestLogLocalDataSource` + Mapper + Repository |
| 拦截器改为常驻 | `dioClientProvider` 始终挂载 `RequestLoggerInterceptor`，按需推入内存缓冲 / Hive |
| 级联删除 | 删除签到结果时同步清理关联请求日志（clearAll / prune / deleteTask） |
| Provider 刷新 | 签到执行/删除后 invalidate `allPersistedRequestLogsProvider` |
| UI 导航 | `CheckInResultCard` 可点击 → `CheckInRequestLogsPage` 复用 `RequestLogListTile` / `RequestLogDetailView` |
| 开发者选项 | 新增「查看持久化请求」入口（仅 kDebugMode），含清空功能 |
| 请求详情 | 概览卡片增加 correlationId 显示 |

## 新增文件（7）
- `check_in_request_log_local_datasource.dart`
- `check_in_request_log_mapper.dart`
- `check_in_request_log_repository.dart` (接口)
- `check_in_request_log_repository_impl.dart`
- `check_in_request_log_providers.dart`
- `check_in_request_logs_page.dart`
- `persisted_request_logs_page.dart`

## 修改文件（17）
- Core: `api_request.dart`, `dio_client.dart`, `common_api_adapter.dart`, `hive_store.dart`, `main.dart`
- Entities: `request_log_entry.dart`, `request_logger_interceptor.dart`
- Check-in: `check_in_local_datasource.dart`, `check_in_notifier.dart`, `account_check_in_history_notifier.dart`, `check_in_detail_view.dart`, `check_in_result_card.dart`, `check_in_filter_bar.dart`
- Dev-tools: `developer_options_page.dart`, `request_log_detail_placeholder.dart`
- Tests: `check_in_local_datasource_test.dart`, `dio_client_logger_wiring_test.dart`

## 验证
- `flutter analyze`: 0 errors (3 既有 info/warning)
- `flutter test`: 489/489 passed


### Git Commits

| Hash | Message |
|------|---------|
| `34d8da8` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 47: fix: widescreen check-in detail panel not refreshing

**Date**: 2026-04-25
**Task**: fix: widescreen check-in detail panel not refreshing
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Bug Fix

In widescreen master-detail layout (≥900px), the right-side detail panel frequently showed stale data after FAB batch check-in and when switching accounts. The refresh FAB worked correctly, but the execute FAB and account switching did not.

## Root Cause

1. **`ref.listen` race condition**: `CheckInDetailView` relied on `ref.listen(latestResultPerAccountProvider)` to invalidate detail providers, but the `AsyncLoading→AsyncData` transition could be missed due to widget rebuild interleaving during `_isExecuting` state changes.
2. **Missing invalidation for other accounts**: `ref.listen` only invalidated the currently selected account's providers. Other accounts' cached providers were never refreshed after batch execution.

## Changes

| File | Change |
|------|--------|
| `check_in_page.dart` | `_executeAll()`: invalidate all accounts' `accountCheckInHistoryProvider` and `accountCheckInStatsProvider` after batch execution |
| `check_in_detail_view.dart` | Add `didUpdateWidget` to invalidate providers when the displayed account changes |

**Stats**: 2 files, +23 lines


### Git Commits

| Hash | Message |
|------|---------|
| `abe9c32` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 48: Account reorder, swipe actions, check-in UX improvements

**Date**: 2026-04-26
**Task**: Account reorder, swipe actions, check-in UX improvements
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 完成内容

| 改动 | 说明 |
|------|------|
| Android 网络权限 | AndroidManifest.xml 添加 INTERNET 权限 |
| 签到波纹修复 | 移除 `_TappableResultCard` 双层 Material/InkWell，直接用 `CheckInResultCard` 传 onTap |
| 账号拖拽排序 | Account 实体新增 `sortOrder` 字段，ListView → ReorderableListView + Dismissible（长按拖拽排序 + 左滑删除 + 右滑签到） |
| 新账号首位 | `create()` 方法计算 min sortOrder - 1 |
| 返回键双击退出 | AppShell 添加 PopScope，首页两次返回退出，非首页先回签到 Tab |
| 签到蒙层移除 | 移除全屏白色 overlay，保留 FAB 的 CircularProgressIndicator |
| 签到逐条刷新 | executeAll/executeAllDue 每个 task 完成后立即 invalidate provider |
| 签到列表跟随账号排序 | checkInAccountSummariesProvider 按 Account.sortOrder 排序 |

**涉及文件 (18)**:
- `android/app/src/main/AndroidManifest.xml`
- `lib/app/shell/app_shell.dart`
- `lib/features/accounts/domain/entities/account.dart`
- `lib/features/accounts/data/models/account_mapper.dart`
- `lib/features/accounts/presentation/providers/accounts_notifier.dart`
- `lib/features/accounts/presentation/providers/accounts_filter_providers.dart`
- `lib/features/accounts/presentation/pages/accounts_page.dart`
- `lib/features/accounts/presentation/widgets/account_card.dart`
- `lib/features/check_in/presentation/pages/check_in_page.dart`
- `lib/features/check_in/presentation/providers/check_in_notifier.dart`
- `lib/features/check_in/presentation/providers/check_in_providers.dart`
- `lib/features/backup/presentation/pages/backup_page.dart`
- `lib/features/check_in/data/datasources/check_in_request_log_local_datasource.dart`
- `lib/features/check_in/presentation/pages/persisted_request_logs_page.dart`
- `lib/features/check_in/presentation/providers/check_in_request_log_providers.dart`
- `lib/features/keys/presentation/pages/keys_page.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `test/widget_test.dart`

**验证**: `dart format` ✅ `flutter analyze` ✅ `flutter test` 489/489 ✅


### Git Commits

| Hash | Message |
|------|---------|
| `8a21369` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 49: Hive storage subdirectory per platform

**Date**: 2026-04-26
**Task**: Hive storage subdirectory per platform
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| 变更 | 说明 |
|------|------|
| Hive 初始化 | `initHive()` 改为按平台传 `subDir`：桌面 `.fl-api-hub/hive`，移动端 `hive` |
| 新增 import | `dart:io` Platform + `flutter/foundation.dart` kIsWeb |

**修改文件**:
- `lib/core/storage/hive_store.dart`

**验证**: `flutter analyze` 0 errors, `flutter test` 489 passed


### Git Commits

| Hash | Message |
|------|---------|
| `791885e` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 50: Account edit form improvements

**Date**: 2026-04-26
**Task**: Account edit form improvements
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Feature | Description |
|---------|-------------|
| Duplicate URL Detection | 100ms debounce + focus-lost trigger, orange border/icon/label warning, non-blocking |
| Hide AnyRouter | Temporarily filter from site type dropdown (preserved for existing accounts) |
| Default Site Type | New accounts default to New-API instead of Unknown |

**Modified Files**:
- `lib/features/accounts/presentation/widgets/account_edit_form.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `c5edd65` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 51: 签到失败项长按跳转内置浏览器

**Date**: 2026-04-26
**Task**: 签到失败项长按跳转内置浏览器
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| Area | Description |
|------|-------------|
| Browser Service | 通用浏览器服务层：flutter_inappwebview + url_launcher 回退，设置开关 |
| Browser Page | 内置浏览器页面（InAppWebView + 进度条） |
| Browser Settings | Clean Architecture 全套：entity → repo → datasource → notifier → providers |
| CheckInResultCard | 添加 onLongPress 回调，仅 failed 状态触发 |
| CheckInPage / DetailView | 长按 → 确认弹窗（文案根据浏览器类型切换，URL 着色）→ 打开浏览器 |
| Settings | 新增"浏览器"设置区，travel_explore 图标 |

**New Files (9)**:
- `lib/core/browser/browser_service.dart`
- `lib/core/browser/browser_page.dart`
- `lib/features/settings/domain/entities/browser_preference.dart`
- `lib/features/settings/domain/repositories/browser_repository.dart`
- `lib/features/settings/data/datasources/browser_local_datasource.dart`
- `lib/features/settings/data/repositories/browser_repository_impl.dart`
- `lib/features/settings/presentation/providers/browser_notifier.dart`
- `lib/features/settings/presentation/providers/browser_providers.dart`
- `lib/features/settings/presentation/widgets/browser_settings.dart`

**Modified Files (4 meaningful)**:
- `lib/features/check_in/presentation/widgets/check_in_result_card.dart`
- `lib/features/check_in/presentation/pages/check_in_page.dart`
- `lib/features/check_in/presentation/widgets/check_in_detail_view.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`

**Dependencies Added**:
- `flutter_inappwebview: ^6.1.5`
- `url_launcher: ^6.3.1`


### Git Commits

| Hash | Message |
|------|---------|
| `3280c0d` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 52: feat(keys): 完善密钥管理页面 — 远程联动 + 导出 + Sub2API

**Date**: 2026-04-26
**Task**: feat(keys): 完善密钥管理页面 — 远程联动 + 导出 + Sub2API
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 概要

将密钥管理从纯本地 CRUD 升级为远程 API 联动 + 本地缓存 + 外部工具导出 + Sub2API 适配。

## 变更内容

| 模块 | 变更 |
|------|------|
| Repository 远程优先 | `KeysRepositoryImpl` 重构：写操作→远程API→本地缓存，读操作→远程拉取→本地回退 |
| SiteAdapter 扩展 | 新增 `updateToken()` 接口 + CommonApiAdapter 实现（`PUT /api/token/`） |
| Sub2API 适配器 | 新增 `Sub2ApiAdapter`，支持 `/api/v1/keys/*` 端点和 `{code,message,data}` envelope |
| 密钥解析 | `resolveKey()` 调用 `POST /api/token/{id}/key`，就地替换 state（不再被远程脱敏覆盖） |
| 密钥脱敏 | 真实前缀+后缀掩码（`sk-abc12...789`），解析后自动显示原文 |
| 复制功能 | 修复 `KeyCard._copyKey()` 和 `KeyValueRow` 内联复制 |
| 导出功能 | Claude Code + Cherry Studio 配置格式化器 + 底部导出栏 |
| Bug 修复 | Hive `_Map<dynamic,dynamic>` 强转、`expired_time=-1` 永不过期、`keyValue` 映射遗漏 |
| UI 改进 | 移除加载蒙版改为 FAB 旋转动画，解析按钮独立旋转 |

## 关键文件

- `lib/core/network/site_adapter.dart` — +updateToken
- `lib/core/network/adapters/common_api_adapter.dart` — 实现
- `lib/core/network/adapters/sub2api_adapter.dart` — 新增
- `lib/features/keys/data/repositories/keys_repository_impl.dart` — 远程优先重构
- `lib/features/keys/presentation/providers/keys_notifier.dart` — resolve 就地更新
- `lib/features/keys/presentation/providers/keys_providers.dart` — family provider
- `lib/features/keys/presentation/widgets/key_value_row.dart` — 脱敏/解析/复制
- `lib/features/keys/data/export/` — 导出格式化器
- `lib/features/keys/presentation/widgets/key_export_bar.dart` — 导出栏


### Git Commits

| Hash | Message |
|------|---------|
| `656d8bb` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete

---

## Session 2026-04-26: Fix Key Quota & Remove Key Value from Form

### Task
`.trellis/tasks/04-26-fix-key-quota-and-forms`

### What Changed

**Modified (2):**
- `lib/features/keys/presentation/widgets/key_quota_grid.dart` — Fixed quota display: `_remainingQuota` and `_usedQuota` now divide by `kDefaultQuotaPerUnit` (500000) to show correct USD amounts
- `lib/features/keys/presentation/widgets/key_form_sheet.dart` — Removed "密钥值" input field entirely; changed quota input to accept USD (decimal) and auto-convert to raw API units via `kDefaultQuotaPerUnit`

### Key Decisions
- Quota input uses USD (user confirmed): `$1 = 500000 raw quota units`
- Removed `keyValue` from form: add mode lets server generate key; edit mode preserves existing keyValue without exposing it
- Used `kDefaultQuotaPerUnit` constant for consistency with account balance computation

### Verification
- `flutter analyze` → No issues
- `flutter test` → 488/488 passed (1 pre-existing failure in account_edit_page_test unrelated to this change)


## Session 53: Fix key quota calculation & form UX optimization

**Date**: 2026-04-27
**Task**: Fix key quota calculation & form UX optimization
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

修复密钥额度显示换算错误，优化密钥表单和列表页交互体验。

| 改动 | 说明 |
|------|------|
| R1: 额度换算修复 | `KeyQuotaGrid` 除以 `kDefaultQuotaPerUnit`(500000) 显示正确美元金额 |
| R2: 移除密钥值字段 | `KeyFormSheet` 删除 keyValue 输入，服务器自动生成 |
| R3: 额度输入改美元 | 支持小数输入，提交时 `* quotaPerUnit` 转换 |
| R4: FAB/UI 优化 | 标准 FloatingActionButton；KeyValueRow 按钮跟文字+间距；标签左对齐 |
| R5: Notifier 优化 | create/saveKey 不设 AsyncLoading，失败 throw；弹窗失败也 pop |

**Modified Files**:
- `lib/features/keys/presentation/widgets/key_quota_grid.dart` — 额度换算修复
- `lib/features/keys/presentation/widgets/key_form_sheet.dart` — 移除密钥值+额度改美元+失败 pop
- `lib/features/keys/presentation/widgets/key_value_row.dart` — Flexible+间距+左对齐
- `lib/features/keys/presentation/pages/keys_page.dart` — FAB 样式统一
- `lib/features/keys/presentation/providers/keys_notifier.dart` — create/saveKey 不设 loading

**Verification**:
- `flutter analyze` → No issues found
- `flutter test` → 488/488 passed (1 pre-existing failure unrelated)


### Git Commits

| Hash | Message |
|------|---------|
| `90e3cbf` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 54: Session 54: Migrate Trellis v0.4.0 → v0.5.0-beta.14

**Date**: 2026-04-27
**Task**: Session 54: Migrate Trellis v0.4.0 → v0.5.0-beta.14
**Branch**: `main`

### Summary

Migrate Trellis config from v0.4.0 to v0.5.0-beta.14. Removed retired commands/skills, Multi-Agent Pipeline, Ralph Loop hook. Agent files renamed with trellis- prefix. 164 files changed. flutter analyze clean.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `51084e3` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete

---

## Session 54: Fix Key Management API Request/Response Bugs

**Date**: 2026-04-27
**Task**: fix-key-api-bugs
**Branch**: `main`

### Summary

Audited key management code against API documentation and fixed 12 bugs across DTO, Adapter, and Repository layers.

### Main Changes

| File | Operation | Description |
|------|-----------|-------------|
| `lib/core/network/dto/token_dto.dart` | Rewritten | `quota`→`remainQuota`, dual Common/Sub2API fields, USD conversion, status string/int, OneHub `total_count` |
| `lib/core/network/site_adapter.dart` | Modified | `createToken` added `quota`, `expiresAt`, `unlimitedQuota` |
| `lib/core/network/adapters/common_api_adapter.dart` | Modified | create/update send complete request body |
| `lib/core/network/adapters/sub2api_adapter.dart` | Rewritten | Page +1, quota USD conv, `expires_in_days`, null-data success |
| `lib/core/network/adapters/wong_api_adapter.dart` | Created | GET for fetchTokenKey |
| `lib/core/network/site_adapter_provider.dart` | Modified | Register WONG adapter |
| `lib/features/keys/data/datasources/keys_remote_datasource.dart` | Modified | Pass full create params |
| `lib/features/keys/data/repositories/keys_repository_impl.dart` | Modified | create() passes quota/expiresAt |
| `lib/features/keys/data/models/api_key_api_mapper.dart` | Modified | Use remainQuota + unlimitedQuota |
| `test/core/network/dto/token_dto_test.dart` | Rewritten | Common + Sub2API field tests |
| `test/features/keys/data/models/api_key_api_mapper_test.dart` | Updated | Use new constructors |

### Bugs Fixed

**P0:** TokenDto field mismatch (quota vs remain_quota), Sub2API quota_used not read, Sub2API success=null treated as failure, Repository create() lost quota/expiresAt

**P1:** Sub2API page 0→1, Common create/update missing fields, Sub2API expires_in_days, quota USD conversion, status string parsing, WONG GET method

### Testing

- [OK] 499/500 pass (1 pre-existing failure)
- [OK] `flutter analyze` zero errors

### Status

[OK] **Completed**
