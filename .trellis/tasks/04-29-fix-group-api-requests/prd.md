# brainstorm: 修复分组相关 API 请求

## Goal

对照 `docs/API 文档/Group.request.md` 参考文档，审查并修复 Flutter 端所有分组相关 API 请求，确保端点、请求格式、响应解析与文档一致。

## Requirements

1. **GroupDto 添加 ratio 字段**：增加 `double? ratio`，各后端正确解析倍率
2. **新建 DoneHubAdapter**：继承 OneHubAdapter，覆盖 `fetchGroups()` 支持分页端点 `GET /api/group/?page=&size=`；DoneHub 的 `fetchUserGroups` 回退到 Common（`/api/user/self/groups`）
3. **Sub2API 双端点合并**：`fetchGroups()` 并行请求 `/api/v1/groups/available` + `/api/v1/groups/rates`，合并 ratio
4. **修复 DoneHub 适配器注册**：`site_adapter_provider.dart` 中 `SiteType.doneHub` 映射到新的 DoneHubAdapter

## Acceptance Criteria

- [ ] `GroupDto` 包含 `double? ratio` 字段
- [ ] Common `fromCommonUserGroup` 正确解析 ratio
- [ ] OneHub `fromOneHubUserGroup` 正确解析 ratio
- [ ] Sub2API `fromSub2ApiGroup` 从 rates 合并 ratio
- [ ] DoneHubAdapter 继承 OneHubAdapter，fetchGroups 使用分页端点
- [ ] `site_adapter_provider.dart` DoneHub 映射到 DoneHubAdapter
- [ ] Sub2API fetchGroups 并行请求 available + rates
- [ ] `flutter analyze` 无新增 warning
- [ ] 新增/更新的 adapter 层单元测试通过

## Definition of Done

- Tests added/updated（adapter 层单元测试覆盖分组方法）
- `flutter analyze` clean
- 所有端点与 API 参考文档一致

## Technical Approach

### Subtask 1: GroupDto 添加 ratio + 各后端解析更新
- `group_dto.dart`: 添加 `double? ratio` 字段
- `fromCommonUserGroup`: 从 `json['ratio']` 读取
- `fromOneHubUserGroup`: 从 `json['ratio']` 读取
- `fromSub2ApiGroup`: ratio 由外部合并后传入（因为需要 rates 端点数据）

### Subtask 2: Sub2API 双端点合并
- `sub2api_adapter.dart`: `fetchGroups()` 改为并行请求 available + rates
- 新增 `_fetchGroupRates()` 请求 `/api/v1/groups/rates`
- 合并逻辑：rates[String(groupId)] → ratio，fallback 到 rate_multiplier → 1

### Subtask 3: DoneHubAdapter
- 新建 `donehub_adapter.dart`，继承 OneHubAdapter
- 覆盖 `fetchGroups()`: 先尝试 OneHub 的 user_group_map → fallback 到 DoneHub 分页端点
- 新增 `_fetchDoneHubSiteGroups()` 使用 `GET /api/group/?page=1&size=100` 分页
- 更新 `site_adapter_provider.dart` 注册映射

## Decision (ADR-lite)

**Context**: DoneHub 的分组端点与 Common/OneHub 不同，需要独立适配器
**Decision**: 新建 DoneHubAdapter 继承 OneHubAdapter，覆盖 `fetchGroups()` 支持分页
**Consequences**: 增加一个 adapter 文件，但保持架构一致性；DoneHub 分组数据更准确

## Out of Scope

- AxonHub 适配器（不在当前 SiteType 枚举中）
- Octopus 适配器（当前使用 CommonAdapter fallback 可工作）
- 渠道管理中的分组功能
- UI 层改动

## Technical Notes

- 关键文件：`group_dto.dart`, `common_api_adapter.dart`, `onehub_adapter.dart`, `sub2api_adapter.dart`, `site_adapter_provider.dart`, `site_type.dart`
- API 文档：`docs/API 文档/Group.request.md`
- 分页工具：DoneHub 使用 `GET /api/group/?page=&size=`，需循环翻页直到全部获取
