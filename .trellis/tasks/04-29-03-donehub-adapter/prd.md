# 新建 DoneHubAdapter：继承 OneHubAdapter，支持分页分组端点

## Goal

新建 `DoneHubAdapter` 继承 `OneHubAdapter`，覆盖 `fetchGroups()` 以支持 DoneHub 特有的分页分组端点 `GET /api/group/?page=&size=`。更新 `site_adapter_provider.dart` 注册映射。

## Requirements

- 新建 `lib/core/network/adapters/donehub_adapter.dart`
- DoneHubAdapter 继承 OneHubAdapter
- 覆盖 `fetchGroups()`: 先尝试 OneHub user_group_map → fallback 到 DoneHub 分页端点
- `_fetchDoneHubSiteGroups()` 使用 `GET /api/group/?page=1&size=100` 循环翻页
- 使用 Common 的 `fetchSiteGroupsFallback()` 不适用于 DoneHub（端点不同）
- 去重逻辑：提取 symbol → trim → filter → Set 去重
- 更新 `site_adapter_provider.dart`：`SiteType.doneHub` → `doneHubAdapter`

## Files to create/modify

- `lib/core/network/adapters/donehub_adapter.dart`（新建）
- `lib/core/network/site_adapter_provider.dart`（修改注册）

## API 参考文档细节

- Endpoint: `GET /api/group/`（注意末尾斜杠）
- Query: `page` (从1开始), `size` (默认100)
- Response envelope: `DoneHubDataResult<DoneHubUserGroupRaw>` → `{ data, page, size, total_count }`
- `data[].symbol` 是分组标识符
- 分页循环：`fetchAllItems` 模式，最大 100 页

## Acceptance Criteria

- [ ] DoneHubAdapter 正确继承 OneHubAdapter
- [ ] fetchGroups 使用正确的 DoneHub 分页端点
- [ ] 分组 symbol 去重处理
- [ ] site_adapter_provider 正确映射 DoneHub
- [ ] `flutter analyze` 无新增 warning
