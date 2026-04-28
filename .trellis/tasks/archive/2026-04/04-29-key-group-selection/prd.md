# 密钥管理支持分组选择

## Goal

密钥新建和编辑表单支持选择分组（从 API 端获取分组列表），获取密钥时从密钥字段读取分组信息并显示在管理站点下方。需要覆盖 Common / OneHub / Sub2API 三种后端家族的分组端点差异。

## What I already know

* API 文档定义了分组端点：
  - Common: `GET /api/user/self/groups`（用户分组）+ `GET /api/group`（站点全部分组）
  - OneHub: `GET /api/user_group_map`（用户分组映射，含额外字段）
  - Sub2API: `GET /api/v1/groups/available` + `GET /api/v1/groups/rates`
  - Octopus: 不适用（通道管理替代密钥管理）
* API 响应中 `ApiToken.group` 字段为分组名称字符串（可选）
* `CreateTokenRequest.group` 字段用于创建/更新时指定分组
* 当前 `TokenDto.fromJson()` 未解析 `group` 字段
* 当前 `ApiKey` 实体无 `group` 字段
* `common_api_adapter` 创建/更新时 `group: ''` 硬编码空字符串
* `key_form_sheet.dart` 无分组选择器

## Assumptions (temporary)

* 分组选择为可选操作（允许空分组/使用默认分组）
* 分组列表在打开表单时一次性获取（无需分页）
* **分组获取策略：优先获取用户分组，失败时回退到站点全部分组**
  - Common: 先 `GET /api/user/self/groups` → 回退 `GET /api/group`
  - OneHub: 先 `GET /api/user_group_map` → 回退 `GET /api/group`
  - Sub2API: `GET /api/v1/groups/available`（无回退，此端点已包含全部可用分组）
* Sub2API 使用 `GET /api/v1/groups/available` 获取分组
* Octopus 不支持分组选择（跳过）

## Requirements

### R1: 数据层 — 分组 DTO 与实体扩展

1. 新建 `GroupDto`：解析各后端家族的分组 API 响应
   - Common/OneHub: `{ desc, ratio }` 格式
   - Sub2API: `{ id, name, description, rate_multiplier }` 格式
   - 统一转换为 `{ name: String, description: String? }` 简化结构
2. `TokenDto` 添加 `group` 字段，`fromJson` 解析 `json['group']`
3. `ApiKey` 实体添加 `group` 字段（`String?`，分组名称）
4. `ApiKey.copyWith` 添加 `group` 参数

### R2: API 层 — SiteAdapter 分组方法

5. `SiteAdapter` 新增 `fetchGroups(ApiRequest)` 方法
6. `CommonApiAdapter` 实现：
   - 优先调用 `GET /api/user/self/groups`（返回 `Record<string, {desc, ratio}>`，提取 key 作为分组名）
   - 失败时回退 `GET /api/group`（返回 `string[]`）
   - 返回 `Result<List<GroupDto>>`
7. `OneHub` 覆盖：优先调用 `GET /api/user_group_map`（返回 `Record<string, OneHubUserGroupInfo>`），失败时回退 Common 的 `GET /api/group`
8. `Sub2ApiAdapter` 实现：调用 `GET /api/v1/groups/available`，从 `Sub2ApiGroupData[]` 提取 `name` 字段
9. Octopus 不实现（返回空列表）

### R3: 创建/更新令牌传递分组参数

10. `SiteAdapter.createToken` 签名添加 `String? group` 可选参数
11. `SiteAdapter.updateToken` 签名添加 `String? group` 可选参数
12. `CommonApiAdapter` 实现：`group` 写入 request body
13. `Sub2ApiAdapter` 实现：`group` 名称 → `group_id` 映射（需先查询分组列表）
14. KeysRemoteDataSource / KeysRepositoryImpl 透传 group 参数

### R4: UI 层 — 表单分组选择器

15. `KeyFormSheet` 添加分组下拉选择器（`DropdownButtonFormField<String?>`）
    - 位置：过期时间字段之后、提交按钮之前
    - 选项：从 API 获取的分组列表 + "默认（不指定）"选项
    - 编辑模式预选现有分组
    - 选择账号后自动加载该账号的分组列表
16. 新建 `groupsProvider` (family provider，按 accountId) 获取分组列表

### R5: UI 层 — 密钥卡片显示分组

17. 密钥卡片（KeyCard）在管理站点下方显示分组信息
    - 仅当 `group` 非空时显示
    - 使用 Chip 样式，与现有 UI 风格一致

## Acceptance Criteria

- [ ] TokenDto.fromJson 正确解析 API 响应中的 group 字段
- [ ] ApiKey 实体包含 group 字段，copyWith 支持更新 group
- [ ] SiteAdapter.fetchGroups 方法存在，各适配器正确实现
- [ ] Common 适配器调用 GET /api/group 返回分组列表
- [ ] Sub2API 适配器调用 GET /api/v1/groups/available 返回分组列表
- [ ] 创建令牌时表单显示分组下拉，选择后传递到 API
- [ ] 编辑令牌时表单预选当前分组，可更改
- [ ] 密钥卡片显示分组信息（在管理站点下方）
- [ ] 无分组时 UI 不显示分组标签（无空占位）
- [ ] 切换账号后分组列表自动刷新

## Definition of Done

- `flutter analyze` 无 warning
- 分组选择器在 Common / Sub2API 两种后端正常工作
- 离线/网络错误时分组选择器优雅降级（显示空列表 + 提示）

## Out of Scope

- Octopus 分组支持（通道管理架构不适用）
- 分组倍率（ratio）的 UI 展示
- 分组管理（CRUD 分组本身）
- 分组搜索/筛选密钥列表
- 模型限制（model_limits）选择器

## Technical Notes

### 分组 API 端点差异

| 后端 | 站点全部分组 | 用户分组 |
|------|------------|---------|
| Common | `GET /api/group` → `string[]` | `GET /api/user/self/groups` → `Record<string, {desc, ratio}>` |
| OneHub | 复用 Common | `GET /api/user_group_map` → `Record<string, OneHubUserGroupInfo>` |
| Sub2API | `GET /api/v1/groups/available` → `Sub2ApiGroupData[]` | 不适用 |
| Octopus | 不适用 | 不适用 |

### 修改文件清单

**新增：**
- `lib/core/network/dto/group_dto.dart` — 分组 DTO
- `lib/features/keys/presentation/providers/groups_providers.dart` — 分组 Provider

**修改：**
- `lib/core/network/dto/token_dto.dart` — 添加 group 字段
- `lib/core/network/site_adapter.dart` — 添加 fetchGroups 方法 + create/update group 参数
- `lib/core/network/adapters/common_api_adapter.dart` — 实现分组获取 + 传递 group 参数
- `lib/core/network/adapters/sub2api_adapter.dart` — 实现分组获取（如有）
- `lib/features/keys/domain/entities/api_key.dart` — 添加 group 字段
- `lib/features/keys/data/datasources/keys_remote_datasource.dart` — 传递 group
- `lib/features/keys/data/repositories/keys_repository_impl.dart` — 传递 group
- `lib/features/keys/presentation/widgets/key_form_sheet.dart` — 添加分组选择器
- `lib/features/keys/presentation/widgets/key_card.dart` — 显示分组标签
- `lib/features/keys/presentation/providers/keys_notifier.dart` — 传递 group 参数
