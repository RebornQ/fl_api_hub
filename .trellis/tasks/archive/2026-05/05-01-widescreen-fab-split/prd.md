# feat: 宽屏模式 FAB 拆分 - 左侧添加/刷新，右侧保存/删除

## Goal

在宽屏模式（≥900px）下，将当前统一在主 Scaffold 右下角的 FAB 组拆分到 SplitPane 的两个面板中：
- **左侧账号列表面板**：添加 FAB + 刷新 FAB
- **右侧账号详情面板**：保存 FAB + 删除 FAB（新增）

窄屏模式保持原有 FAB 行为不变。

## What I already know

**当前 FAB 实现（accounts_page.dart）**:
- `_buildFabGroup()` 在主 Scaffold 的 `floatingActionButton` 位置
- 三种 FAB：添加（primary）、刷新（secondary container）、保存（tertiary，dirty 时切换替换添加+刷新）
- 宽屏使用 `SplitPane`（左侧 40% 列表 + 右侧 60% 详情面板）
- `_AccountsDetailPanel` 是 `ConsumerStatefulWidget`，包含 `AccountEditForm` + `save()` 方法
- `_detailDirtyNotifier` 跟踪详情面板的 dirty 状态
- `_detailPanelKey` 用于外部调用 `panel.save()`

**删除功能已有实现**:
- `_confirmDelete()` 方法已有完整的确认对话框 + 删除逻辑（第975-1006行）
- 删除后清除 `selectedAccountIdProvider`（若删除的是当前选中账号）
- 左滑删除（`Dismissible`）也已存在

**窄屏编辑页（account_edit_page.dart）**:
- 有独立的保存 FAB（tertiary 颜色，dirty 时显示）
- 无删除 FAB

## Assumptions (temporary)

- 宽屏模式下删除 FAB 仅在编辑已有账号时显示（新增模式不显示）
- 删除 FAB 放在保存 FAB 上方（与其他 FAB 组的纵向排列风格一致）
- 删除 FAB 使用 error/destructive 颜色方案以示警告
- 窄屏模式行为完全不变
- SplitPane 两个子面板可以各自包裹 Scaffold 来获得独立的 FAB 位置

## Open Questions

~~1. 删除 FAB 的颜色方案？~~ → ✅ 使用 error 相关颜色，与删除操作的破坏性语义一致
~~2. 宽屏新增账号时右侧面板如何处理？~~ → ✅ 宽屏添加 FAB 保持推全屏页面（AccountEditPage.push），右侧面板仅显示已有账号编辑
~~3. 删除 FAB 是否需要确认对话框？~~ → ✅ 是，复用现有的 `_confirmDelete()` 逻辑
~~4. 宽屏新增模式的入口和状态管理？~~ → ✅ 不需要新增模式，添加 FAB 保持推全屏页面

## Requirements (evolving)

### R1: 左侧面板独立 FAB（添加 + 刷新）

- 左侧账号列表面板（SplitPane leftChild）包裹独立 Scaffold
- Scaffold.floatingActionButton 放置添加 FAB + 刷新 FAB
- FAB 组样式保持与现有一致（添加 primary，刷新 secondary container）
- 不再有 dirty 状态切换逻辑（保存 FAB 移到右侧）
- 刷新 FAB 旋转动画保持不变
- 添加 FAB 行为保持不变：调用 `AccountEditPage.push()` 推全屏页面

### R2: 右侧面板独立 FAB（保存 + 删除）

- 右侧详情面板（_AccountsDetailPanel）包裹独立 Scaffold
- Scaffold.floatingActionButton 放置：
  - **保存 FAB**（tertiary 颜色）：当 form dirty 时显示
  - **删除 FAB**（error 颜色）：当编辑已有账号时显示
- 两个 FAB 纵向排列（删除在上，保存在下）
- 保存 FAB 复用现有 `_onWideSave()` 逻辑，loading 状态保持不变
- 删除 FAB 复用现有 `_confirmDelete()` 逻辑
- 空态（无选中账号）时不显示任何 FAB

### R3: 主 Scaffold FAB 移除

- 宽屏模式下主 Scaffold 不再显示 `floatingActionButton`
- 窄屏模式保持原有 FAB 组行为完全不变

### R4: 删除 FAB 行为

- 点击删除 FAB 弹出确认对话框（复用 `_confirmDelete` 风格）
- 确认后删除账号，清除选中状态，右侧面板回到空态
- 删除 FAB 使用 error 颜色方案
- 仅在有选中账号时显示（selectedId != null 且账号存在）

### R5: 窄屏模式 - AccountEditPage 添加删除 FAB

- 窄屏编辑页面（`AccountEditPage`）添加删除 FAB
- 删除 FAB 放在保存 FAB 上方，纵向排列
- 删除 FAB 使用 error 颜色方案，与宽屏一致
- 仅在编辑模式（`widget.account != null`）显示，新增模式不显示
- 点击后弹出确认对话框，确认后删除账号并返回列表
- 确认对话框复用 `_confirmDelete` 风格

### R6: 窄屏模式 - 主列表 FAB 保持不变

- 窄屏 FAB 组保持原有逻辑（添加 + 刷新，dirty 时切换保存）
- 窄屏无删除 FAB 在主列表（删除在编辑页面中）

## Acceptance Criteria (evolving)

- [x] 宽屏模式下，左侧面板右下角显示添加 FAB + 刷新 FAB
- [x] 宽屏模式下，右侧面板右下角显示保存 FAB（dirty 时）+ 删除 FAB（有选中账号时）
- [x] 宽屏刷新 FAB 点击后图标旋转动画正常
- [x] 宽屏保存 FAB loading 状态正常（点击后显示 spinner）
- [x] 宽屏删除 FAB 点击后弹出确认对话框
- [x] 宽屏删除确认后，选中状态清除，右侧面板回到空态
- [x] 宽屏空态（无选中账号）时右侧不显示 FAB
- [x] 窄屏模式行为完全不变
- [x] 窄屏编辑页面（AccountEditPage）添加删除 FAB
- [x] 窄屏删除 FAB 仅在编辑模式显示，新增模式不显示
- [x] 窄屏删除 FAB 点击后弹出确认对话框，确认后删除并返回列表
- [x] `flutter analyze` 无新增 warning/error（仅有一个预期的 unused_element warning）

## Definition of Done (team quality bar)

- [x] `flutter analyze` clean（仅有一个预期的 unused_element warning）
- [x] 所有 accounts 相关测试通过（134 passed, 2 skipped）
- [ ] 手动验证宽屏/窄屏两种布局的 FAB 行为
- [ ] 键盘导航（ArrowUp/ArrowDown）不受影响
- [ ] 编辑模式（拖拽排序）不受影响
- [ ] 长按弹出菜单不受影响

## Out of Scope (explicit)

- 窄屏主列表 FAB 行为修改
- 删除 FAB 的 undo 功能
- SplitPane 比例调整
- 宽屏模式下右侧面板新增账号表单（添加 FAB 保持推全屏页面）

## Technical Notes

**关键文件**:
- `lib/features/accounts/presentation/pages/accounts_page.dart` — 宽屏 FAB 重构
- `lib/features/accounts/presentation/pages/account_edit_page.dart` — 添加删除 FAB

**实现策略**:
- 方案 A（推荐）：为 SplitPane 的 leftChild 和 rightChild 各自包裹 Scaffold
  - leftChild 的 Scaffold 放添加+刷新 FAB
  - rightChild（_AccountsDetailPanel）内部包裹 Scaffold 放保存+删除 FAB
  - 需要 `NeverScrollableScrollPhysics` 避免嵌套 Scaffold 的滚动冲突
- 方案 B：使用 Stack + Positioned 手动定位 FAB
  - 更灵活但维护性差

**删除 FAB 颜色方案**:
- `backgroundColor: colorScheme.error`
- `foregroundColor: colorScheme.onError`
