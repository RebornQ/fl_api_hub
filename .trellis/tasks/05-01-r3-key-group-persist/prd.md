# R3: 修复密钥解析后分组消失

## Goal

修复密钥解析后分组字段消失的问题，确保 `group` 值正确持久化到本地存储。

## Root Cause

- `ApiKeyApiMapper.toEntity` 正确从 API 获取并设置 `group` 字段
- `ApiKeyMapper.toMap` 没有序列化 `group` 字段到 Hive
- `ApiKeyMapper.fromMap` 没有反序列化 `group` 字段

导致：密钥解析后 `group` 正确显示，但保存到本地时丢失，重启 App 后消失。

## Requirements

1. `ApiKeyMapper.toMap` 添加 `group` 字段序列化
2. `ApiKeyMapper.fromMap` 添加 `group` 字段反序列化
3. 确保解析密钥后 `group` 值正确持久化

## Acceptance Criteria

- [ ] 解析密钥后 group 字段正确显示
- [ ] 重启 App 后 group 字段仍存在
- [ ] `flutter analyze` 无错误

## Technical Approach

**文件**：`lib/features/keys/data/models/api_key_mapper.dart`

修改 `toMap` 方法（约第 14-24 行）：

```dart
static Map<String, dynamic> toMap(ApiKey apiKey) => {
  'id': apiKey.id,
  'accountId': apiKey.accountId,
  'name': apiKey.name,
  'keyValue': apiKey.keyValue,
  'quota': apiKey.quota,
  'usedQuota': apiKey.usedQuota,
  'expiresAt': apiKey.expiresAt?.toIso8601String(),
  'createdAt': apiKey.createdAt.toIso8601String(),
  'updatedAt': apiKey.updatedAt.toIso8601String(),
  'group': apiKey.group, // 新增
};
```

修改 `fromMap` 方法（约第 27-41 行）：

```dart
static ApiKey fromMap(Map<String, dynamic> map) {
  return ApiKey(
    id: map['id'] as String,
    accountId: map['accountId'] as String,
    name: map['name'] as String,
    keyValue: map['keyValue'] as String?,
    quota: map['quota'] as int?,
    usedQuota: map['usedQuota'] as int? ?? 0,
    expiresAt: map['expiresAt'] != null
        ? DateTime.parse(map['expiresAt'] as String)
        : null,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
    group: map['group'] as String?, // 新增
  );
}
```

## Files

- `lib/features/keys/data/models/api_key_mapper.dart`

## Out of Scope

- 不修改 `ApiKey` 实体定义
- 不修改 `ApiKeyApiMapper`
- 不修改 group 的获取或显示逻辑