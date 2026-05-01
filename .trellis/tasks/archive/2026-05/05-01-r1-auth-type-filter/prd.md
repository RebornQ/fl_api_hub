# R1: 账号编辑表单认证方式调整

## Goal

账号编辑表单的认证方式下拉框永久移除 "无" 选项，临时隐藏 Cookie 选项。

## Requirements

1. 认证方式下拉框移除 `AuthType.none`（"无"）选项
2. 认证方式下拉框隐藏 `AuthType.cookie` 选项（代码层面过滤，不删除枚举值）
3. 下拉框只显示 `Access Token` 一个选项

## Acceptance Criteria

- [ ] 账号编辑表单认证方式下拉框只显示 "Access Token"
- [ ] `flutter analyze` 无错误
- [ ] 现有账号（包括使用 Cookie 认证的账号）编辑时仍能正确显示其认证类型

## Technical Approach

**文件**：`lib/features/accounts/presentation/widgets/account_edit_form.dart`

修改 `_buildCredentialsFields()` 方法中的 `DropdownButtonFormField<AuthType>`（约第 441-454 行）：

```dart
DropdownButtonFormField<AuthType>(
  key: const ValueKey('authTypeField'),
  initialValue: _authType,
  decoration: const InputDecoration(labelText: '认证方式'),
  items: AuthType.values
      .where((t) => t == AuthType.accessToken) // 只保留 Access Token
      .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
      .toList(),
  onChanged: (t) {
    if (t == null) return;
    setState(() => _authType = t);
  },
),
```

## Files

- `lib/features/accounts/presentation/widgets/account_edit_form.dart`

## Out of Scope

- 不修改 `AuthType` 枚举定义
- 不修改 `site_type.dart` 中 `SiteType.defaultAuthType` 的定义
- 不影响已有账号的认证方式存储和读取