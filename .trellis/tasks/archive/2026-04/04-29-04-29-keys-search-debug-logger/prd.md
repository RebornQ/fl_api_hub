# feat: 密钥账号搜索 + 请求记录器 kDebug 锁定

## Goal

两项独立但相关的开发者体验优化：密钥页账号选择器支持搜索过滤、请求记录器在调试模式下锁定开启。

## Requirements

### S1: 密钥列表账号选择器支持搜索

- AccountSelector 从简单 DropdownButtonFormField 改为可搜索下拉框
- 用户输入关键词后，下拉列表实时过滤匹配的账号（name 字段 case-insensitive contains）
- 清空搜索后恢复全部账号
- 搜索交互友好：自动展开、清除按钮、无匹配提示

### S2: 请求记录器 kDebug 模式锁定开启

- `requestLoggerEnabledProvider` 在 `kDebugMode` 下初始值改为 `true`
- 开发者选项页面的开关在 `kDebugMode` 下禁用（锁定开启），不可手动关闭
- 非 debug 模式行为不变：默认关闭，可手动开关

## Acceptance Criteria

- [ ] S1: 账号下拉框输入关键词可过滤匹配账号
- [ ] S1: 选择账号后搜索状态正确重置
- [ ] S2: kDebugMode 下请求记录器默认开启且开关禁用
- [ ] S2: Release 模式下行为与当前完全一致
- [ ] `flutter analyze` clean

## Definition of Done

- Lint / typecheck clean
- 相关测试覆盖

## Out of Scope

- S1: 搜索结果高亮匹配文本
- S1: 搜索历史/记忆
- S2: kDebugMode 下允许手动关闭记录器

## Technical Notes

### S1 涉及文件

- `lib/features/keys/presentation/widgets/account_selector.dart` — 改为可搜索下拉
- `lib/features/keys/presentation/pages/keys_page.dart` — 传入方式可能需适配

### S2 涉及文件

- `lib/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart` — 初始值 kDebugMode 判断
- `lib/features/dev_tools/request_logger/presentation/pages/developer_options_page.dart` — SwitchListTile 禁用逻辑

### 现有实现摘要

- AccountSelector: StatelessWidget，纯 DropdownButtonFormField，接收 `List<Account> accounts`
- requestLoggerEnabledProvider: `StateProvider<bool>((ref) => false)`，不持久化
- developer_options_page.dart 已 import `package:flutter/foundation.dart`（kDebugMode 可用）
