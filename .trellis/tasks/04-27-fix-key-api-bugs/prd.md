# fix: 密钥管理 API 请求/响应 Bug 修复

## Goal

对照 `docs/API 文档/Key.request.md`，审查并修复密钥管理功能中所有 API 请求构建和响应解析的 bug，确保 Common 层和 Sub2API 适配器的 API 调用正确无误。

## What I already know

### 代码审查发现的关键 Bug（按严重程度排序）

**P0 — 数据错误/丢失（Critical）**

1. **TokenDto 字段名不匹配 Common API**
   - 现状：`TokenDto.fromJson` 读取 `json['quota']` 和 `json['used_quota']`
   - Common API 实际返回：`remain_quota`（剩余额度）和 `used_quota`（已用额度）
   - 结果：Common API 的 `quota` 始终为 null，`used_quota` 正确

2. **TokenDto 字段名不匹配 Sub2API**
   - Sub2API 实际返回：`quota`（总额度 USD）和 `quota_used`（已用额度 USD）
   - 现状：`usedQuota` 读取 `json['used_quota']` → Sub2API 下始终为 null
   - 且 Sub2API 的 quota 是 USD，需 `× 500000` 转为内部单位，当前无转换

3. **Sub2API create/update 成功时 data 为 null → 被误判为失败**
   - API 文档：`{"code": 0, "message": "success", "data": null}`
   - `_unwrapEnvelope` 返回 null → adapter 返回 Failure
   - 所有 Sub2API 的创建和更新操作都会"假失败"

4. **Repository.create() 不传递 quota/expiresAt**
   - `KeysRepositoryImpl.create()` 只传 `name` 给 adapter
   - 表单收集的 quota 和 expiresAt 数据完全丢失

**P1 — API 调用参数错误（High）**

5. **Sub2API listTokens 页码从 1 开始，但 adapter 直接传 0**
   - API 文档：`page` 参数从 **1** 开始
   - Common API：`p` 参数从 **0** 开始
   - 当前 Sub2API adapter 直接透传 page=0

6. **Common createToken 缺少必填字段**
   - API 要求：`name`, `remain_quota`, `expired_time`, `unlimited_quota`, `model_limits_enabled`, `model_limits`, `allow_ips`, `group`
   - 当前只发：`{'name': name}`

7. **Common updateToken 缺少必填字段**
   - API 要求全部 create 字段 + `id`
   - 当前只发：`id`, `name`, `remain_quota`, `expired_time`

8. **Sub2API createToken 应使用 `expires_in_days` 而非 `expires_at`**
   - API 文档：创建用 `expires_in_days`（天数），更新用 `expires_at`（ISO 时间戳）
   - 当前 create 和 update 都没有处理过期时间

9. **Sub2API quota 应为 USD（浮点数），但接口定义为 `int?`**
   - Sub2API 的 quota 是 USD 浮点值，需要转换
   - 创建时：内部单位 ÷ 500000 → USD
   - 更新时：内部单位 ÷ 500000 → USD，且需加上已用额度

**P2 — 站点差异未处理（Medium）**

10. **WONG 后端 key 解析应使用 GET 而非 POST**
    - API 文档：WONG 用 `GET /api/token/{id}/key`
    - Common adapter 硬编码 `POST`
    - 无 WONG 专属 adapter 覆盖

11. **Sub2API status 字段为字符串但 DTO 按 int 解析**
    - Sub2API：`"active"` / `"inactive"` / `"quota_exhausted"` 等
    - TokenDto：`json['status'] as int?` → 始终 null

12. **OneHub 分页格式不同（`data` vs `items`, `total_count` vs `total`）**
    - `TokenListDto.fromJson` 用 `json['items'] ?? json['data']` 可部分兼容
    - 但 OneHub 的 total 字段名是 `total_count`，当前读不到

## Assumptions (temporary)

- SiteAdapter 接口签名变更需要同步更新 Common 和 Sub2API 两个实现
- DTO 字段映射需要在 `TokenDto.fromJson` 中同时支持 Common 和 Sub2API 的字段名
- Sub2API 的 USD ↔ quota 转换在 DTO/mapper 层处理
- WONG 暂无独立 adapter，需要评估是否新建或在现有 adapter 中处理

## Open Questions

- WONG 后端的 key 解析差异是否需要在此次修复中处理？（当前项目可能暂无 WONG 用户）

## Requirements

### P0 — 必须修复

1. **TokenDto 字段映射修复**：同时支持 Common (`remain_quota`) 和 Sub2API (`quota`, `quota_used`) 字段名
2. **Sub2API 成功响应处理**：create/update 响应 data 为 null 时不应视为失败
3. **Repository.create() 传递完整参数**：quota 和 expiresAt 必须传给 adapter
4. **Sub2API quota 单位转换**：USD ↔ 内部 quota 的双向转换

### P1 — 应该修复

5. **Sub2API 页码偏移**：listTokens 的 page 参数从 0 转为 1
6. **Common createToken 补充默认字段**：`unlimited_quota`, `model_limits_enabled`, `model_limits`, `allow_ips`, `group` 发送合理默认值
7. **Sub2API createToken 使用 `expires_in_days`**
8. **Sub2API status 字符串解析**：`"active"` → 1, 其他 → 0
9. **WONG 后端 key 解析使用 GET 而非 POST**：新建 WONG adapter 或在 Common adapter 中按 siteType 区分

### P2 — 可以后续处理

10. **OneHub 分页 total_count 兼容**
11. **补充 model_limits / allow_ips / group 等高级字段到表单**

## Acceptance Criteria

- [ ] Common API: 创建令牌发送完整请求体（name + remain_quota + expired_time + unlimited_quota + model_limits_enabled 等默认值）
- [ ] Common API: 列表返回的 `remain_quota` 和 `used_quota` 正确解析到 DTO
- [ ] Common API: 更新令牌发送完整请求体
- [ ] Sub2API: 列表返回的 `quota`（USD）和 `quota_used`（USD）正确转换并解析
- [ ] Sub2API: 创建/更新成功（data=null）不被误判为失败
- [ ] Sub2API: 创建使用 `expires_in_days` 而非 `expires_at`
- [ ] Sub2API: listTokens 页码从 1 开始
- [ ] Sub2API: quota 正确在 USD 和内部单位间转换
- [ ] Sub2API: status 字符串（active/inactive）正确映射为数字
- [ ] Repository.create() 传递 quota 和 expiresAt 给 adapter
- [ ] WONG 后端: fetchTokenKey 使用 GET 方法
- [ ] 现有测试全部通过，新增/更新相关测试
- [ ] `flutter analyze` 无 warning

## Definition of Done

- 所有 P0 和 P1 bug 已修复
- Tests added/updated
- `flutter analyze` 无 warning
- Sub2API 和 Common API 的请求/响应对齐 API 文档

## Out of Scope

- 新增 model_limits / allow_ips / group 表单字段（P2）
- Octopus 通道管理
- OneHub total_count 兼容（P2）
- 导出功能修改

## Technical Approach

### 修改文件清单

**核心修改：**

1. `lib/core/network/dto/token_dto.dart`
   - `TokenDto.fromJson`: 同时读取 `remain_quota` 和 `quota`，读取 `used_quota` 和 `quota_used`
   - 添加 Sub2API USD → 内部单位转换标记
   - `status` 同时处理 int 和 string 类型

2. `lib/core/network/site_adapter.dart`
   - `createToken` 接口扩展：增加 `quota`, `expiresAt`, `unlimitedQuota` 等参数

3. `lib/core/network/adapters/common_api_adapter.dart`
   - `createToken`: 发送完整请求体（补充默认字段）
   - `updateToken`: 发送完整请求体

4. `lib/core/network/adapters/sub2api_adapter.dart`
   - `createToken`: 发送 Sub2API 格式（name + quota USD + expires_in_days）
   - `updateToken`: quota USD 转换 + expires_at
   - `listTokens`: page 从 0 转为 1
   - `_unwrapEnvelope`: 成功时 data=null 不视为失败

5. `lib/features/keys/data/datasources/keys_remote_datasource.dart`
   - `createToken`: 传递完整参数

6. `lib/features/keys/data/repositories/keys_repository_impl.dart`
   - `create()`: 传递 quota 和 expiresAt 给 remote data source

7. `lib/features/keys/data/models/api_key_api_mapper.dart`
   - 可能需要处理 Sub2API 的 quota 转换

**测试修改/新增：**

8. 更新现有 TokenDto 单元测试
9. 更新 CommonApiAdapter 测试
10. 更新 Sub2ApiAdapter 测试
11. 更新 KeysRepositoryImpl 测试

## Technical Notes

### Sub2API quota 转换规则

```
Common: remain_quota 已是内部单位（×500000），直接使用
Sub2API: quota 是 USD，需要 × 500000 转为内部单位
  - 读取时: quota_usd × 500000 → remain_quota_internal
  - 创建时: remain_quota_internal ÷ 500000 → quota_usd
  - 更新时: (remain_quota_internal + used_quota_internal) ÷ 500000 → quota_usd
```

### Sub2API create vs update 差异

```
创建: expires_in_days (天数, 0=永不过期)
更新: expires_at (ISO 8601 时间戳, 空字符串=永不过期)
```

### Sub2API status 映射

```
"active"          → 1 (启用)
"inactive"        → 0 (禁用)
"quota_exhausted" → 0 (额度耗尽)
"expired"         → 0 (已过期)
```

### API 字段对照

| 语义 | Common API | Sub2API | TokenDto 现有 | 应该支持 |
|------|-----------|---------|-------------|---------|
| 剩余额度 | `remain_quota` | `quota` (USD) | `quota` ← json['quota'] | `remain_quota` + `quota` |
| 已用额度 | `used_quota` | `quota_used` (USD) | `usedQuota` ← json['used_quota'] | `used_quota` + `quota_used` |
| 状态 | `status` (int) | `status` (string) | `status` as int? | int + string 映射 |
| 过期时间 | `expired_time` (unix) | `expires_at` (ISO) | fromJson 已处理两种格式 | OK |
| 创建时间 | `created_time` (unix) | `created_at` (ISO) | fromJson 已处理两种格式 | OK |
