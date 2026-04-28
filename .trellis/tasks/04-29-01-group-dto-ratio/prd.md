# GroupDto 添加 ratio 字段及各后端解析更新

## Goal

为 `GroupDto` 添加 `double? ratio`（倍率）字段，确保各后端适配器正确解析并传递 ratio 数据。

## Requirements

- `GroupDto` 新增 `double? ratio` 字段
- `fromCommonUserGroup`: 从 `json['ratio']` 读取 ratio（Common 响应的 `UserGroupInfo` 中包含 ratio）
- `fromOneHubUserGroup`: 从 `json['ratio']` 读取 ratio（OneHub 原始数据中包含 ratio）
- `fromSub2ApiGroup`: 改为接受可选 ratio 参数（由外部合并后传入）
- `fromCommonSiteGroup`: ratio 保持 null（站点分组列表不返回倍率）
- 更新 `toString()`/`==`/`hashCode` 以包含 ratio

## Files to modify

- `lib/core/network/dto/group_dto.dart`

## Acceptance Criteria

- [ ] GroupDto 包含 `double? ratio` 字段
- [ ] Common/OneHub/Sub2API 工厂方法正确解析 ratio
- [ ] `flutter analyze` 无新增 warning
