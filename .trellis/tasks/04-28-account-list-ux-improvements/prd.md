# feat: 账号列表三项 UX 改进

## Goal

三项独立但相关的账号列表 UX 优化：限制未开启自动签到的账号右划签到、密钥页账号选择器跟随账号列表排序、搜索支持标签名匹配。

## Requirements

### S1: 未开启自动签到的账号禁止右划手动签到

- 账号列表右划行为：仅当 `account.checkIn.autoCheckInEnabled == true` 时允许右划签到
- 未开启自动签到的账号（无论 enabled 与否），右划方向完全禁用，只保留左滑删除
- 当前代码 `accounts_page.dart:640-642` 用 `account.enabled` 控制 `Dismissible.direction`，需改为同时检查 `account.checkIn.autoCheckInEnabled`

### S2: 密钥页账号选择器排序跟随账号列表

- `AccountSelector` 下拉列表中的账号顺序应与账号列表页一致
- 当前 `keys_page.dart:252` 传入 `accountsProvider` 的原始列表（Hive box 顺序），未排序
- 排序规则与 `filteredAccountsProvider` 一致：enabled 优先 + disabled 沉底，每组内按 `sortOrder` 升序

### S3: 账号列表搜索支持标签名匹配

- 搜索框输入的关键词应能匹配账号关联的标签名（`Tag.name`）
- 当前搜索仅覆盖 `name`、`baseUrl`、`notes`，需增加对 `account.tagIds` → `tagsProvider` 的关联查询
- 匹配逻辑：case-insensitive `contains`，与现有字段一致

## Acceptance Criteria

- [ ] S1: 未开启 `autoCheckInEnabled` 的账号右划无签到响应，只可左滑删除
- [ ] S1: 开启 `autoCheckInEnabled` 的账号行为不变（右划签到 + 左滑删除）
- [ ] S2: 密钥页 AccountSelector 账号顺序与账号列表页一致
- [ ] S3: 搜索 "生产" 能匹配到有 "生产" 标签的账号
- [ ] S3: 标签搜索不影响现有搜索（name/baseUrl/notes）行为
- [ ] `flutter analyze` 无错误
- [ ] `flutter test` 全部通过

## Definition of Done

- 相关测试覆盖新增逻辑
- Lint / typecheck / CI green
- 代码格式化通过 `dart format .`

## Out of Scope

- 不修改 Tag 实体或 tagsProvider 的数据结构
- 不修改搜索 UI（hint 文案等）
- 不涉及签到逻辑本身的改动

## Technical Notes

### S1 涉及文件

- `lib/features/accounts/presentation/pages/accounts_page.dart`
  - L640-642: `Dismissible.direction` 条件改为 `account.checkIn.autoCheckInEnabled`
  - L619-636: `checkInBg` 背景也需同步条件化

### S2 涉及文件

- `lib/features/keys/presentation/pages/keys_page.dart` (L252)
  - 排序方案选择：
    - A) 在 keys_page 中引入排序逻辑（内联或提取函数）
    - B) 新建共享 provider（如 `sortedAccountsProvider`），两个页面共用
  - 推荐 A 方案（简单、YAGNI），排序逻辑仅几行

### S3 涉及文件

- `lib/features/accounts/presentation/providers/accounts_filter_providers.dart`
  - `filteredAccountsProvider` 需 watch `tagsProvider`
  - 搜索逻辑增加 tag name 匹配分支
  - 需处理 tagsProvider 加载中/失败的情况（fallback 为不匹配标签）

## Research Notes

- `Account.checkIn` 类型为 `CheckInConfig`，有 `autoCheckInEnabled` 字段
- `Account.tagIds` 为 `List<String>`，引用 `Tag.id`
- `tagsProvider` 提供 `List<Tag>`，`Tag` 有 `name` 字段
- 账号列表排序已在 `filteredAccountsProvider` 中实现（enabled 优先 + sortOrder 升序）
