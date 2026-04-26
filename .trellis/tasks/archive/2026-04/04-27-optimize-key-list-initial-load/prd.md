# 密钥列表首次加载优化 — 账号下拉默认未选中

## Goal

优化密钥管理页面的首次加载体验：进入页面时账号下拉框默认未选中（显示"请选择账号"），不自动加载任何密钥数据，用户手动选择账号后才触发加载。减少不必要的 API 调用，提升用户感知的响应速度。

## What I already know

* 当前 `keys_page.dart` L75-92 在 `accounts.whenData` 回调中自动选中第一个账号
* `_selectedAccountId` 初始为 `null`，但被 `addPostFrameCallback` 立即设为 `list.first.id`
* `keysProvider` 是 family provider，参数为 accountId，watch 后自动触发加载
* `AccountSelector` 当前 hint 为 "选择一个账号"（有账号时）/ "请先添加账号"（无账号时）
* 当 `_selectedAccountId == null` 时，keys 已经返回空列表（L95-97），不触发加载
* 账号被删除时的回退逻辑（L82-91）也是自动选中第一个账号

## Requirements

1. 移除账号列表加载后的自动选中逻辑
2. AccountSelector 的 hint 文案改为"请选择账号"
3. 未选中账号时，页面显示引导性空状态（"请在上方选择一个账号以查看密钥"）
4. 账号被删除时，清空选中状态（不自动选下一个），除非只剩一个账号
5. 下拉框支持"取消选中"（回到未选中状态），可选实现

## Acceptance Criteria

- [ ] 打开 App 后首次进入密钥页面，下拉框显示"请选择账号"，不触发密钥 API 调用
- [ ] 手动选择账号后，密钥列表正常加载显示
- [ ] 切换账号时，密钥列表正确刷新
- [ ] 账号被删除后，选中状态清空（或回退到合理状态）
- [ ] 未选中账号时的空状态 UI 友好
- [ ] 现有功能不受影响：搜索、CRUD、导出、刷新

## Definition of Done

- `flutter analyze` 无 warning
- `flutter test` 全部通过
- 相关 widget test 更新

## Out of Scope

- 记住上次选中的账号（跨 session 持久化）— 可作为后续优化
- 下拉框的"取消选中"功能 — 可作为后续增强

## Technical Approach

### 核心变更

**1. `keys_page.dart`** — 移除自动选中 + 调整空状态
- 删除 L75-92 的 `accounts.whenData` 自动选中逻辑
- 只保留"被删除账号的回退"（清空选中而非自动选下一个）
- `_buildNoAccountsState` 分为两种：无账号 vs 未选择账号

**2. `account_selector.dart`** — 更新 hint 文案
- 有账号但未选中时 hint 改为"请选择账号"
- 下拉框初始值为 `null`，不预设 `initialValue`

**3. 测试更新** — 调整 widget test 以适配新行为

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `keys_page.dart` | 修改 | 移除自动选中、调整空状态 UI |
| `account_selector.dart` | 修改 | hint 文案更新 |
| `test/features/keys/presentation/` | 修改 | 适配新行为 |

## Implementation Plan (batches)

### Batch 1: 核心逻辑 + UI（单批次即可完成）

1. `keys_page.dart`: 移除自动选中逻辑，更新空状态判断
2. `account_selector.dart`: 更新 hint 文案
3. 运行 `flutter analyze` + `flutter test` 验证

> 预计改动量：< 50 行，单批次完成
