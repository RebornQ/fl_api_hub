# fix: 四项 UI 和功能修复

## Goal

修复四个独立的 UI 和功能问题，涉及账号编辑表单、账号列表排序、密钥分组持久化、Android 备份文件保存。

## What I already know

### R1: 认证方式调整

- 当前 `AuthType` 枚举有三种类型：`accessToken`、`cookie`、`none`
- `account_edit_form.dart` 下拉框显示所有 `AuthType.values`
- **确认需求**：
  - 永久移除 "无"（`none`）选项
  - 临时隐藏 `Cookie` 选项（代码中过滤，不删除枚举值）

### R2: 账号禁用后重新启用排序

- `AccountsNotifier.toggleEnabled` 只切换 `enabled` 状态，不更新 `sortOrder`
- 当前排序逻辑：enabled 优先 + sortOrder 升序
- 禁用账号的 `sortOrder` 可能是旧值，重新启用后会排在错误位置

### R3: 密钥解析后分组消失

- `ApiKeyApiMapper.toEntity` 正确从 API 获取 `group` 字段
- **问题根源**：`ApiKeyMapper`（本地持久化 mapper）缺少 `group` 字段：
  - `toMap` 没有序列化 `group`
  - `fromMap` 没有反序列化 `group`

### R4: Android 备份保存文件无反应

- `BackupFileDataSource.saveToFile` 使用 `FilePicker.platform.saveFile`
- **问题平台**：Android
- 代码注释说"桌面平台只返回路径，需要自己写入 bytes"
- Android 上 `saveFile` 行为可能不同

## Requirements

### R1: 认证方式调整

1. 账号编辑表单的认证方式下拉框临时隐藏 `Cookie` 选项
2. 移除 `none`（"无"）认证方式选项
3. 下拉框只显示 `Access Token` 一个选项

### R2: 账号禁用后重新启用排序

4. 禁用账号重新启用时，自动将 `sortOrder` 设为当前所有启用账号的最大值 + 1
5. 确保重新启用的账号排在启用列表的最后

### R3: 密钥解析后分组消失

6. `ApiKeyMapper.toMap` 添加 `group` 字段序列化
7. `ApiKeyMapper.fromMap` 添加 `group` 字段反序列化
8. 确保解析密钥后 `group` 值正确持久化

### R4: 移动端备份保存文件无反应

9. 检测移动端 `saveFile` 返回值处理
10. 确保移动端能正确写入文件并返回路径

## Acceptance Criteria

- [ ] R1: 账号编辑表单认证方式下拉框只显示 Access Token
- [ ] R2: 禁用账号重新启用后排在启用列表最后
- [ ] R3: 解析密钥后 group 字段正确显示，重启 App 仍存在
- [ ] R4: 移动端点击"保存到文件"能成功保存备份文件

## Definition of Done

- `flutter analyze` 无错误
- `flutter test` 全部通过
- 手动测试四项修复

## Out of Scope

- 不修改 `AuthType` 枚举定义本身（保留 `cookie` 和 `none` 值以兼容已有数据）
- 不修改账号列表的 UI 布局
- 不修改密钥列表的其他功能

## Technical Approach

### R1: 认证方式调整

**文件**：`lib/features/accounts/presentation/widgets/account_edit_form.dart`

修改 `_buildCredentialsFields()` 方法中的下拉框，过滤掉 `cookie` 和 `none`：

```dart
items: AuthType.values
    .where((t) => t == AuthType.accessToken)
    .map((t) => DropdownMenuItem(value: t, child: Text(t.displayName)))
    .toList(),
```

### R2: 账号禁用后重新启用排序

**文件**：`lib/features/accounts/presentation/providers/accounts_notifier.dart`

修改 `toggleEnabled` 方法，当 `!account.enabled` → `true` 时，计算新的 `sortOrder`：

```dart
// If enabling, place at the end of enabled accounts
int newSortOrder = account.sortOrder;
if (!account.enabled) {
  final enabledAccounts = current.where((a) => a.enabled).toList();
  final maxSortOrder = enabledAccounts.fold<int>(
    -1,
    (max, a) => a.sortOrder > max ? a.sortOrder : max,
  );
  newSortOrder = maxSortOrder + 1;
}

final updated = account.copyWith(
  enabled: !account.enabled,
  sortOrder: newSortOrder,
  updatedAt: DateTime.now(),
);
```

### R3: 密钥解析后分组消失

**文件**：`lib/features/keys/data/models/api_key_mapper.dart`

修改 `toMap` 和 `fromMap`：

```dart
// toMap
'group': apiKey.group,

// fromMap
group: map['group'] as String?,
```

### R4: 移动端备份保存文件无反应

**文件**：`lib/features/backup/data/datasources/backup_file_datasource.dart`

需要检查 `FilePicker.platform.saveFile` 在移动端的返回值行为。如果移动端返回 `null` 但实际上文件已保存，需要调整逻辑。

可能的方案：
- 检查 `FilePicker.platform.saveFile` 是否在某些情况下返回 `null` 但文件已存在
- 或者使用 `getDirectoryPath` + 手动写入的方式替代

## Implementation Plan

这四个修复相对独立，可以在单个任务中完成：

1. **Batch 1**: R1 + R3（简单字段修改）
2. **Batch 2**: R2（逻辑修改）
3. **Batch 3**: R4（需调研移动端行为）

## Technical Notes

### 相关文件

- `lib/features/accounts/presentation/widgets/account_edit_form.dart`
- `lib/features/accounts/presentation/providers/accounts_notifier.dart`
- `lib/features/keys/data/models/api_key_mapper.dart`
- `lib/features/backup/data/datasources/backup_file_datasource.dart`

### R4 调研备注

根据 [file_picker](https://pub.dev/packages/file_picker) 文档，`saveFile` 在不同平台行为不同：
- 桌面端：返回用户选择的路径，需要手动写入
- 移动端（Android/iOS）：行为可能不同，需要测试

可能需要检查：
1. `selectedPath` 是否为 `null` 但文件已保存
2. 是否需要使用 `path_provider` 获取目录后手动创建文件
