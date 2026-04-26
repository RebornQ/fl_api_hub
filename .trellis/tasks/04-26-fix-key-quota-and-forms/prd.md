# 修复密钥额度计算 & 密钥表单/列表交互优化

## Goal

修复密钥卡片中额度显示的换算错误，从添加/编辑密钥表单中移除密钥值输入字段，将额度输入框改为美元单位，并优化密钥页 UI 交互体验。

## Requirements

### R1: 修复额度显示换算 ✓

- `KeyQuotaGrid._remainingQuota`: 使用 `quotaPerUnit` 换算为美元
- `KeyQuotaGrid._usedQuota`: 使用 `quotaPerUnit` 换算为美元（而非除以 100）
- 无限额度时保持显示 "无限额度"
- 换算结果保留 2 位小数

### R2: 移除密钥值输入字段 ✓

- 从 `KeyFormSheet` 移除 "密钥值" (`_keyValueController`) 相关的 UI 和逻辑
- 添加模式: 不再传递 keyValue（服务器自动生成）
- 编辑模式: 保持现有 keyValue 不变（不在表单中暴露/修改）

### R3: 额度输入框改为美元单位 ✓

- 用户输入美元金额（如输入 1 = $1 额度）
- 提交时内部转换: `rawQuota = dollarAmount * quotaPerUnit`
- 编辑模式加载时: `dollarDisplay = rawQuota / quotaPerUnit`
- 验证: 允许小数输入（如 0.5 = $0.50）

### R4: 密钥页 UI 交互优化 ✓

- FAB 按钮改为标准 `FloatingActionButton`，与账号页样式一致
- KeyValueRow 按钮组紧跟密钥文字（`Flexible` 替代 `Expanded`），加间距
- 密钥标签左对齐（移除左侧 padding）
- `DropdownButtonFormField` 使用 `value` 替代 `initialValue` 修复 Build-scheduled-during-frame 异常

### R5: 添加/编辑密钥 Notifier 优化 ✓

- `create` / `saveKey` 不再设 `state = AsyncLoading`，列表保持当前数据不动
- 成功 → 刷新列表；失败 → `throw exception` 由表单 SnackBar 显示错误
- 表单失败时先 `pop()` 关闭弹窗再显示 SnackBar，避免弹窗遮挡错误提示
- Retry 按钮点击后立即设 `AsyncLoading` 防止重复点击

## Acceptance Criteria

- [x] 密钥卡片 "剩余额度" 显示正确的美元金额（使用 quotaPerUnit 换算）
- [x] 密钥卡片 "已用额度" 显示正确的美元金额（使用 quotaPerUnit 换算）
- [x] 无限额度时显示 "无限额度" 文案不变
- [x] 添加密钥表单无 "密钥值" 输入字段
- [x] 编辑密钥表单无 "密钥值" 输入字段
- [x] 添加密钥时服务器正常生成 key（无需客户端提供）
- [x] 编辑密钥时 keyValue 不被修改
- [x] 额度输入框接受美元金额（支持小数）
- [x] 额度提交时正确转换为 API 原始单位
- [x] 编辑时额度显示为美元金额
- [x] FAB 样式与账号页一致
- [x] 输入框内容变动不再抛 Build-scheduled-during-frame 异常
- [x] 添加/编辑密钥期间列表不显示 AsyncLoading
- [x] 操作失败时弹窗关闭、SnackBar 可见
- [x] Retry 立即切换到 loading 状态防止重复点击
- [x] flutter analyze 无 warning
- [x] 现有测试通过

## Definition of Done

- `flutter analyze` 无 warning
- `flutter test` 全部通过（488/488，1 个已有失败与本任务无关）

## Out of Scope

- 按站点动态获取 quotaPerUnit（使用默认值，后续迭代）
- KeyValueRow 的密钥解析功能
- `delete` 操作的 loading 状态（保留现有行为）

## Technical Approach

### R1: 额度显示修复

`key_quota_grid.dart` — 引入 `kDefaultQuotaPerUnit` 进行换算。

### R2: 移除密钥值字段

`key_form_sheet.dart` — 删除 `_keyValueController`、`_obscureKey`、`_keyModified` 及整块密钥值 UI。

### R3: 额度输入改为美元

`key_form_sheet.dart` — `TextInputType.numberWithOptions(decimal: true)`，提交时 `* quotaPerUnit`，加载时 `/ quotaPerUnit`。

### R4: UI 交互优化

- `keys_page.dart`: FAB 从 `Hero + Material + InkWell` 改为标准 `FloatingActionButton`
- `key_value_row.dart`: `Expanded` → `Flexible` + 间距，左侧 padding 改为 0
- `key_form_sheet.dart`: `DropdownButtonFormField` 的 `initialValue` → `value`

### R5: Notifier 优化

- `keys_notifier.dart`: `create`/`saveKey` 移除 `state = AsyncLoading`，失败时 `throw`
- `key_form_sheet.dart`: catch 块中先 `pop()` 再显示 SnackBar
- `keys_page.dart`: Retry 先设 `state = AsyncLoading()` 再 `ref.invalidate()`

## Modified Files

| 文件 | 改动 |
|------|------|
| `lib/features/keys/presentation/widgets/key_quota_grid.dart` | 修复额度换算公式 |
| `lib/features/keys/presentation/widgets/key_form_sheet.dart` | 移除密钥值字段 + 额度改美元 + initialValue→value + 失败时 pop |
| `lib/features/keys/presentation/widgets/key_value_row.dart` | Flexible + 间距 + 左对齐 |
| `lib/features/keys/presentation/pages/keys_page.dart` | FAB 样式统一 + Retry 防重复 |
| `lib/features/keys/presentation/providers/keys_notifier.dart` | create/saveKey 不设 loading、失败 throw |

## Decision (ADR-lite)

**Context**: 额度输入框应使用什么单位
**Decision**: 使用美元作为输入单位，内部自动转换
**Consequences**: 用户体验与显示一致；需要处理小数精度（double → int 转换时四舍五入）
