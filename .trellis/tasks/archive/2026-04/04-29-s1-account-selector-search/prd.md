# S1: 密钥列表账号选择器支持搜索

## Goal

将 AccountSelector 从简单 DropdownButtonFormField 改为可搜索下拉框，支持输入关键词实时过滤账号列表。

## Current Behavior

- `account_selector.dart` 是 StatelessWidget，使用 DropdownButtonFormField
- 接收 `List<Account> accounts` 和 `String? selectedId`
- 无搜索/过滤功能，账号多时难以定位

## Target Behavior

- 下拉框顶部增加搜索输入框
- 输入关键词后，下拉列表实时过滤（按 account.name case-insensitive contains）
- 清空搜索恢复全部账号
- 选择账号后关闭下拉并重置搜索
- 无匹配时显示空状态提示

## Technical Approach

将 AccountSelector 从 StatelessWidget 改为 StatefulWidget（或 ConsumerStatefulWidget），内部维护搜索状态。

推荐方案：使用 PopupMenuButton + 搜索 TextField 替代 DropdownButtonFormField，或使用 searchable_dropdown 等模式自行实现。

考虑 YAGNI，建议自行实现而非引入第三方包：
- StatefulWidget 内部维护 `_searchQuery`
- 展开时显示搜索框 + 过滤后的列表
- 选中后关闭并重置搜索

## Files

- `lib/features/keys/presentation/widgets/account_selector.dart` (重写)

## Acceptance Criteria

- [ ] 输入关键词可过滤账号列表
- [ ] 清空搜索恢复全部账号
- [ ] 无匹配时显示友好提示
- [ ] 选中账号后搜索状态重置
- [ ] 排序逻辑不变（enabled 优先 + sortOrder）

## Definition of Done

- `flutter analyze` clean
- 相关 widget test 覆盖
