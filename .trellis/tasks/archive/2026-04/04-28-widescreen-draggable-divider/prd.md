# 宽屏模式分割线拖拽 + 持久化

## Goal

为宽屏模式（≥900px）的 master-detail 分割布局添加可拖拽分割线，用户可自由调整左右面板比例，比例全局共享并持久化到本地存储，重启后恢复。

## Requirements

* 创建可复用 `SplitPane` widget，支持水平二分布局 + 可拖拽分割线
* 分割比例全局共享：拖拽任一页面，所有页面同步
* 使用已有 Hive `KeyValueStore` 持久化 ratio（key: `split_pane_ratio`）
* 默认比例 0.4（40% 左面板），拖拽范围 **0.3–0.5**（30%–50%）
* 拖拽结束（松手时）保存，避免频繁 IO
* 分割线视觉反馈：
  - 默认：`outlineVariant` 40% 透明（淡灰）
  - 悬停：`outline`（较深灰）
  - 拖拽中：`primary`（品牌紫色，最醒目）
* 鼠标悬停分割线时光标变为 `SystemMouseCursors.resizeColumn`
* 迁移 3 个页面：accounts_page / check_in_page / request_logger_page
* 窄屏（<900px）不受影响

## Acceptance Criteria

- [x] 分割线可拖拽，拖拽时左右面板实时调整
- [x] 鼠标悬停分割线时光标变为水平调整图标
- [x] 拖拽范围限制在 **30%–50%**
- [x] 分割线三种视觉状态（默认/悬停/拖拽）颜色不同
- [x] 分割比例在应用重启后恢复
- [x] 3 个宽屏页面全部迁移到 SplitPane widget
- [x] 窄屏模式不受影响
- [x] 现有功能（键盘导航、选中态、FAB、刷新等）不受影响
- [x] `flutter analyze` clean

## Definition of Done

* `flutter analyze` clean ✅
* 手动测试：3 页面拖拽 + 重启恢复
* 单一 widget 复用于所有页面 ✅

## Technical Approach

1. ~~新增 `shared_preferences` 依赖~~ → **复用已有 Hive KeyValueStore**（更轻量）
2. 新建 `SplitPane` widget (`lib/core/widgets/split_pane.dart`)
   - 参数: `leftChild`, `rightChild`, `ratio`, `onRatioChanged`
   - 内部用 `GestureDetector` + `onHorizontalDragUpdate` 管理拖拽
   - `_isHovering` / `_isDragging` 状态追踪分割线高亮
   - 视觉: `VerticalDivider` + 12px hit area + hover/drag cursor
3. 新建 Riverpod provider (`lib/core/storage/split_pane_provider.dart`)
   - `splitPaneRatioProvider`: `Notifier<double>`，启动时从 Hive 读取
   - 拖拽结束时 `onRatioChanged` 调用 provider 更新 + 持久化
4. 替换 3 个页面的 `Row(SizedBox(0.4) + VerticalDivider + Expanded)` → `SplitPane`

## Decision (ADR-lite)

**Context**: 分割比例存储策略需确定
**Decision**: 全局共享一个比例值
**Consequences**: 所有页面行为一致，代码更简洁。若未来需要独立比例，可在 key 中加入页面标识符扩展。

**Context**: 持久化方案选择
**Decision**: 复用已有 Hive KeyValueStore 而非新增 shared_preferences
**Consequences**: 保持依赖最小化，遵循项目现有存储模式。

**Context**: 拖拽范围
**Decision**: 限制在 30%–50%
**Consequences**: 左侧面板不会太窄或太宽，保持 master-detail 布局的可读性。

## Out of Scope

* 水平分割（上下拖拽）
* 双击分割线重置默认（后续增强）
* 分割线动画效果
* 每个页面独立存储比例

## Technical Notes

* 涉及文件:
  - 新建: `lib/core/widgets/split_pane.dart`
  - 新建: `lib/core/storage/split_pane_provider.dart`
  - 修改: `lib/features/accounts/presentation/pages/accounts_page.dart`
  - 修改: `lib/features/check_in/presentation/pages/check_in_page.dart`
  - 修改: `lib/features/dev_tools/request_logger/presentation/pages/request_logger_page.dart`
