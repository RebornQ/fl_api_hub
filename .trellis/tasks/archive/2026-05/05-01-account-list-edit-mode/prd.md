# brainstorm: 账号列表编辑模式

## Goal

为账号列表添加"编辑模式"，将现有的长按拖拽排序功能移入编辑模式，解放非编辑模式的长按功能用于其他交互。编辑模式按钮放置在标题右侧，开启时列表项持续抖动。

## What I already know

**现有实现（accounts_page.dart）**:
- 使用 `ReorderableListView.builder` + `ReorderableDelayedDragStartListener` 实现长按拖拽排序
- `buildDefaultDragHandles: false` 表示自定义拖拽手柄
- 列表项包裹在 `Dismissible` 中支持左滑删除/右滑签到
- 宽屏布局（≥900px）有 master-detail 双列模式
- 标题区域在 `_buildHeader()` 中，仅有"账号管理"标题和副标题

**AccountCard 组件**:
- `ConsumerWidget`，显示账号名称、类型、URL、余额、状态点
- 已有 `isSelected` 参数支持选中效果
- 有 `onTap` 回调

**现有长按行为**:
- `ReorderableDelayedDragStartListener` — 长按后进入拖拽模式
- 无其他长按功能

## Assumptions (temporary)

- 编辑模式仅影响列表交互行为，不影响搜索、筛选、FAB 等其他区域
- 编辑模式下仍可通过点击进入账号详情（保持原有 onTap 行为）
- 宽屏布局也需要支持编辑模式
- **编辑模式行为**：仅拖拽排序 + 抖动，点击仍进入详情页（类似 iOS 图标编辑模式）

## Open Questions

~~1. **编辑模式下点击列表项的行为**~~ → ✅ 已确认：仅拖拽排序 + 抖动，点击保持原行为

## Requirements (evolving)

### R1: 编辑模式状态管理
- 新增 `_isEditMode` 状态（`bool` 字段在 `_AccountsPageState` 中）
- 编辑模式状态影响列表交互行为

### R2: 编辑模式入口按钮
- 在标题栏右侧添加"编辑"按钮（TextButton）
- 非编辑模式显示"编辑"，点击进入编辑模式
- 编辑模式显示"完成"，点击退出编辑模式
- 按钮与标题行同一行，右对齐

### R3: 拖拽排序移入编辑模式
- 非编辑模式：禁用 `ReorderableListView` 的拖拽功能，列表项静态显示
- 编辑模式：启用拖拽排序，改用 `ReorderableDragStartListener`（立即拖拽，无需长按）+ 左侧拖拽图标

### R4: 编辑模式下列表项抖动动画
- 编辑模式开启时，所有列表项开始抖动
- 编辑模式关闭时，停止抖动
- 抖动效果：小幅度左右旋转，周期约 300ms，参考 iOS 图标抖动

### R5: 非编辑模式长按功能解放
- 移除长按拖拽后，长按手势可用于其他功能（本次不定义具体功能，仅禁用拖拽）

## Acceptance Criteria (evolving)

- [ ] 标题栏右侧显示"编辑"按钮，与标题同行右对齐
- [ ] 点击"编辑"按钮进入编辑模式，按钮文字变为"完成"，列表项开始抖动
- [ ] 编辑模式下列表项左侧显示拖拽图标（≡），可立即拖拽排序（无需长按）
- [ ] 编辑模式下点击列表项仍可进入详情页/右侧面板（行为不变）
- [ ] 点击"完成"退出编辑模式，抖动停止，拖拽图标隐藏
- [ ] 非编辑模式下长按列表项无拖拽响应

## Definition of Done (team quality bar)

- Tests added/updated (widget tests for edit mode toggle and animation)
- Lint / typecheck / CI green
- Docs/notes updated if behavior changes
- 抖动动画性能良好（无 jank）

## Out of Scope (explicit)

- 编辑模式下的批量选择/删除功能（本次仅实现拖拽排序 + 抖动效果）
- 编辑模式下的多选/全选功能
- 影响其他页面（签到、密钥等）

## Technical Notes

### 涉及文件
- `lib/features/accounts/presentation/pages/accounts_page.dart`
  - 新增 `_isEditMode` 状态字段
  - 修改 `_buildHeader()` → 改为 Row 布局，左侧标题 + 右侧编辑按钮
  - 修改 `_buildAccountsList()` 条件化拖拽行为

- `lib/features/accounts/presentation/widgets/account_card.dart`
  - 新增 `isEditMode` 参数
  - 新增抖动动画（`AnimationController` + `Transform.rotate`）
  - 编辑模式下左侧显示拖拽图标（`Icons.drag_handle`）

### 技术方案

**抖动动画实现**：
- 在 AccountCard 内部实现，通过 `isEditMode` 参数控制动画启停
- 使用 `AnimationController` + `AnimatedBuilder` + `Transform.rotate`
- 动画参数：旋转 ±0.5°，周期 300ms，repeat(reverse: true)

**拖拽手柄**：
- 非编辑模式：不显示拖拽图标，不响应拖拽
- 编辑模式：显示拖拽图标（≡），使用 `ReorderableDragStartListener` 立即拖拽

**标题栏布局**：
- 原有 `_buildHeader()` 返回 `Column`（标题 + 副标题）
- 改为：外层 Row → 左侧 Expanded(Column) + 右侧 TextButton
- 或使用 `Stack` 叠加按钮在标题行右侧

### 动画参数
- 旋转角度：±0.5°（0.0087 rad）
- 周期：300ms
- 曲线：Curves.easeInOut
