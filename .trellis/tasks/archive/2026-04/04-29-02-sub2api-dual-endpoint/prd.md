# Sub2API 双端点合并：fetchGroups 并行请求 available + rates

## Goal

Sub2API `fetchGroups()` 改为并行请求 `/api/v1/groups/available` + `/api/v1/groups/rates`，合并 ratio 数据后返回完整的 `GroupListDto`。

## Requirements

- `fetchGroups()` 内部并行请求两个端点：
  - `GET /api/v1/groups/available` → 分组列表（含 id, name, description, rate_multiplier）
  - `GET /api/v1/groups/rates` → `Record<string, number>` 分组 ID → 倍率映射
- ratio 优先级：rates 表匹配值 > group.rate_multiplier > 1（默认）
- 合并后的 GroupDto 包含 ratio 字段
- 如果 rates 请求失败，仍从 available 端点获取分组（降级）

## Files to modify

- `lib/core/network/adapters/sub2api_adapter.dart`
- `lib/core/network/dto/group_dto.dart`（如需调整 fromSub2ApiGroup 签名）

## Acceptance Criteria

- [ ] fetchGroups 并行请求 available + rates
- [ ] ratio 按优先级合并：rates > rate_multiplier > 1
- [ ] rates 请求失败时降级到 available only
- [ ] `flutter analyze` 无新增 warning
