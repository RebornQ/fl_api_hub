# 密钥分组 API 参考

> 面向项目开发者的 Group 相关 API 完整参考，覆盖所有后端家族的差异化实现。

## 1. 概述

### 1.1 功能简介

密钥分组（Group）是 All API Hub 中管理 API Key 归属的核心概念。每个 API 密钥可分配到一个分组，分组决定了该密钥的**倍率（ratio）**和**权限范围**。

项目中涉及以下 Group 相关操作：

| 操作 | 对应函数 | 用途 |
|------|----------|------|
| 获取用户分组 | `fetchUserGroups()` | 获取当前登录用户可用的分组列表及其倍率，供密钥创建/编辑时选择 |
| 获取站点全部分组 | `fetchSiteUserGroups()` | 获取站点上所有已定义的分组标识，供管理功能（如渠道编辑）使用 |
| 密钥写入 group 字段 | `createApiToken()` / `updateApiToken()` | 创建或更新密钥时提交分组信息，部分后端需要名称→ID 转换 |

### 1.2 核心类型

以下类型定义于 `src/services/apiService/common/type.ts`：

```typescript
// 分组信息（所有后端归一化后的最终格式）
export interface UserGroupInfo {
  desc: string   // 分组描述/显示名称
  ratio: number  // 分组倍率
}

// 通用分组响应信封（Common / OneHub 系列）
export interface UserGroupsResponse {
  data: Record<string, UserGroupInfo>
  message: string
  success: boolean
}
```

### 1.3 ApiServiceRequest — 框架层请求对象

所有 API 函数均接收 `ApiServiceRequest` 作为第一个参数，定义于 `src/services/apiService/common/type.ts:327`：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `auth` | `AuthConfig` | 是 | 认证配置，见下方 AuthConfig 表格 |
| `baseUrl` | `string` | 是 | API 基础 URL，如 `https://api.example.com` |
| `accountId` | `string` | 否 | 账号 ID，用于标识当前操作的账号 |
| `data` | `Record<string, any>` | 否 | 可扩展的业务数据 |

**AuthConfig**（`src/services/apiService/common/type.ts:298`）：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `authType` | `AuthTypeEnum` | 是 | 认证类型：`cookie` / `access_token` / `none` |
| `cookie` | `string` | 否 | Cookie 字符串（备用方案，DNR 已注入 cookie 头） |
| `accessToken` | `string` | 否 | 访问令牌，用于 Bearer Token 认证 |
| `userId` | `number \| string` | 否 | 用户 ID |
| `refreshToken` | `string` | 否 | Sub2API 专用：refresh token |
| `tokenExpiresAt` | `number` | 否 | Sub2API 专用：access token 过期时间戳（ms） |

### 1.4 后端家族分发机制

函数调用通过 `getApiService(siteType)` 分发到对应后端实现，定义于 `src/services/apiService/index.ts:27`：

```
siteType → 覆盖模块链（从前到后查找，未找到则回退到 commonAPI）
─────────────────────────────────────────────
one-hub   → [oneHubAPI]
done-hub  → [doneHubAPI, oneHubAPI]   // DoneHub 未覆盖时尝试 OneHub
Veloera   → [veloeraAPI]
anyrouter → [anyrouterAPI]
new-api   → [commonAPI]
wong-gongyi → [wongAPI]
sub2api   → [sub2apiAPI]
octopus   → [octopusAPI]
axon-hub  → [axonHubAPI]
default   → [commonAPI]
```

---

## 2. 获取用户分组 (fetchUserGroups)

获取**当前登录用户**有权限使用的分组列表，返回 `Record<string, UserGroupInfo>`。

### 2.1 Common 实现

**适用后端**：New API / One-API / Veloera / anyrouter / wong-gongyi / done-hub（done-hub 未覆盖此函数，回退到 Common）

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user/self/groups` |
| **认证** | Cookie（`auth.cookie` 注入请求头）或 Bearer Token（`auth.accessToken` 作为 `Authorization: Bearer <token>` 头） |
| **缓存** | 默认（由 `fetchApi` 底层决定，无特殊缓存控制） |

**请求参数**：无 query / body 参数。仅通过 `ApiServiceRequest` 注入认证和 baseUrl。

**响应参数**：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `success` | `boolean` | 请求是否成功 |
| `message` | `string` | 响应消息 |
| `data` | `Record<string, UserGroupInfo>` | 分组数据，key 为分组名称 |
| `data.<key>.desc` | `string` | 分组描述 |
| `data.<key>.ratio` | `number` | 分组倍率 |

**响应示例**：

```json
{
  "success": true,
  "message": "",
  "data": {
    "default": { "desc": "默认分组", "ratio": 1 },
    "vip": { "desc": "VIP 用户", "ratio": 0.8 },
    "svip": { "desc": "SVIP 用户", "ratio": 0.5 }
  }
}
```

**错误码**：

| 场景 | 状态码 | 说明 |
|------|--------|------|
| 未登录 / token 过期 | 401 | 认证失败，需重新登录 |
| 无权限 | 403 | 账号无权访问分组接口 |
| 服务器错误 | 5xx | 上游服务异常 |
| 响应格式异常 | — | 抛出 `ApiError`，message 为 "响应数据格式异常" |

---

### 2.2 OneHub 实现

**定义位置**：`src/services/apiService/oneHub/index.ts:102`  
**适用后端**：one-hub、done-hub（done-hub 回退链中包含 oneHubAPI）

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user_group_map` |
| **认证** | 同 Common（Cookie 或 Bearer Token） |
| **缓存** | 默认（无特殊缓存控制） |

**请求参数**：无 query / body 参数。

**原始响应参数**（OneHub 后端返回的原始数据结构）：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `success` | `boolean` | 请求是否成功 |
| `message` | `string` | 响应消息 |
| `data` | `Record<string, OneHubUserGroupInfo>` | 原始分组数据 |
| `data.<key>.id` | `number` | 分组 ID |
| `data.<key>.symbol` | `string` | 分组标识符 |
| `data.<key>.name` | `string` | 分组名称 |
| `data.<key>.ratio` | `number` | 分组倍率 |
| `data.<key>.api_rate` | `number` | API 调用倍率 |
| `data.<key>.public` | `boolean` | 是否公开分组 |
| `data.<key>.promotion` | `boolean` | 是否为促销分组 |
| `data.<key>.min` | `number` | 最小配额限制 |
| `data.<key>.max` | `number` | 最大配额限制 |
| `data.<key>.enable` | `boolean` | 是否启用 |

**转换逻辑**（`src/services/apiService/oneHub/transform.ts:64`）：

```typescript
// transformUserGroup — 将 OneHub 原始数据映射为通用格式
function transformUserGroup(input) {
  const result = {}
  for (const key in input) {
    const group = input[key]
    result[key] = {
      desc: group.name,   // 取 OneHubUserGroupInfo.name 作为 desc
      ratio: group.ratio, // 取 OneHubUserGroupInfo.ratio 作为 ratio
    }
  }
  return result
}
```

> 注意：`symbol`、`api_rate`、`public`、`promotion`、`min`、`max`、`enable` 等字段在转换后**丢弃**，仅保留 `desc` 和 `ratio`。

**原始响应示例**：

```json
{
  "success": true,
  "message": "",
  "data": {
    "default": {
      "id": 1, "symbol": "default", "name": "默认分组",
      "ratio": 1, "api_rate": 1, "public": true,
      "promotion": false, "min": 0, "max": 1000000, "enable": true
    },
    "vip": {
      "id": 2, "symbol": "vip", "name": "VIP 分组",
      "ratio": 0.5, "api_rate": 0.5, "public": false,
      "promotion": true, "min": 100, "max": 5000, "enable": true
    }
  }
}
```

**转换后返回给调用方**：

```json
{
  "default": { "desc": "默认分组", "ratio": 1 },
  "vip": { "desc": "VIP 分组", "ratio": 0.5 }
}
```

---

### 2.3 Sub2API 实现

**定义位置**：`src/services/apiService/sub2api/index.ts:1037`  
**适用后端**：sub2api

| 项目 | 说明 |
|------|------|
| **行为** | 内部并行请求两个端点，合并结果后返回 |
| **认证** | JWT Bearer Token（`auth.accessToken`），支持过期自动刷新（refresh token 自愈） |
| **缓存** | **两个端点均使用 `cache: "no-store"`**，强制每次获取最新数据 |

#### 2.3.1 端点 1：获取可用分组列表

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/v1/groups/available` |
| **响应信封** | `Sub2ApiEnvelope<Sub2ApiGroupData[]>` |

**响应参数**：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `code` | `number` | 业务状态码，`0` 表示成功 |
| `message` | `string` | 响应消息 |
| `data` | `Sub2ApiGroupData[]` | 可用分组列表 |
| `data[].id` | `number \| string` | 分组 ID |
| `data[].name` | `string \| null` | 分组名称 |
| `data[].description` | `string \| null` | 分组描述 |
| `data[].rate_multiplier` | `number \| string \| null` | 分组倍率（备用，优先使用 rates 端点数据） |

#### 2.3.2 端点 2：获取分组倍率

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/v1/groups/rates` |
| **响应信封** | `Sub2ApiEnvelope<Record<string, number>>` |

**响应参数**：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `code` | `number` | 业务状态码，`0` 表示成功 |
| `message` | `string` | 响应消息 |
| `data` | `Record<string, number>` | 分组 ID → 倍率的映射表，key 为 `String(groupId)` |

#### 2.3.3 合并逻辑

`buildSub2ApiUserGroups()` 函数（`src/services/apiService/sub2api/parsing.ts:355`）将两个端点的数据合并：

```
对于 groups 列表中的每个分组：
  1. groupName = trim(group.name)          // 若为空则跳过
  2. groupId   = toIntegerOrNull(group.id) // 若为 null 则跳过
  3. desc      = trim(group.description) || groupName
  4. ratio     = rates[String(groupId)]          // 优先：rates 端点
              || toNumberOrZero(group.rate_multiplier) // 其次：group 自带的 rate_multiplier
              || 1                                    // 默认：1
```

**ratio 取值优先级**（从高到低）：

| 优先级 | 来源 | 端点 |
|--------|------|------|
| 1（最高） | rates 表中匹配的值 | `/api/v1/groups/rates` |
| 2 | group 的 `rate_multiplier` 字段 | `/api/v1/groups/available` |
| 3（fallback） | `1` | 硬编码默认值 |

**响应示例**：

端点 1 (`/api/v1/groups/available`) 返回：
```json
{
  "code": 0,
  "message": "ok",
  "data": [
    { "id": 1, "name": "default", "description": "Default plan", "rate_multiplier": 1.0 },
    { "id": 2, "name": "premium", "description": "Premium plan", "rate_multiplier": 0.5 }
  ]
}
```

端点 2 (`/api/v1/groups/rates`) 返回：
```json
{
  "code": 0,
  "message": "ok",
  "data": { "1": 1, "2": 0.5 }
}
```

合并后返回给调用方：
```json
{
  "default": { "desc": "Default plan", "ratio": 1 },
  "premium": { "desc": "Premium plan", "ratio": 0.5 }
}
```

---

## 3. 获取站点所有分组 (fetchSiteUserGroups)

获取**站点上所有已定义的分组标识**（不限于当前用户），返回 `string[]`。主要用于管理 UI（如渠道编辑中的分组选择）。

### 3.1 Common 实现

**适用后端**：New API / One-API / Veloera / anyrouter / wong-gongyi / one-hub

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/group` |
| **认证** | Cookie 或 Bearer Token |
| **缓存** | 默认 |

**请求参数**：无。

**响应参数**：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| （根级） | `string[]` | 分组标识符数组（从信封 `data` 字段提取） |

**响应示例**：

```json
["default", "vip", "svip", "internal"]
```

> 注意：Common 实现通过 `fetchApiData` 自动提取 `{ success, data, message }` 信封中的 `data` 字段，因此调用方直接收到 `string[]`。

---

### 3.2 DoneHub 实现

**定义位置**：`src/services/apiService/doneHub/index.ts:533`  
**适用后端**：done-hub

| 项目 | 说明 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/group/` |
| **认证** | Cookie 或 Bearer Token |
| **缓存** | 默认 |

**请求参数（Query String）**：

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `page` | `number` | 是 | `1`（起始页） | 页码，从 1 开始，由内部 `fetchAllItems` 循环递增 |
| `size` | `number` | 是 | `100` (`DEFAULT_PAGE_SIZE`) | 每页条数 |

**分页机制**：

- 通过 `fetchAllItems` 工具函数（`src/services/apiService/common/pagination.ts`）自动翻页
- 最大翻页数：`REQUEST_CONFIG.MAX_PAGES = 100`
- 每页 `REQUEST_CONFIG.DEFAULT_PAGE_SIZE = 100` 条
- 理论最大拉取 `100 × 100 = 10000` 个分组

**原始响应信封**（`DoneHubDataResult<DoneHubUserGroupRaw>`）：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `data` | `DoneHubUserGroupRaw[] \| null` | 当前页的分组数据 |
| `page` | `number` | 当前页码 |
| `size` | `number` | 每页条数 |
| `total_count` | `number` | 总条数 |
| `data[].symbol` | `string` | 分组标识符 |

**去重处理**：

```typescript
// 提取 symbol 字段 → trim() → 过滤空字符串 → new Set() 去重 → Array.from()
const symbols = allGroups
  .map((group) => (group?.symbol ?? "").trim())
  .filter(Boolean)
return Array.from(new Set(symbols))
```

> 注意：DoneHub 的 `fetchUserGroups` **未覆盖**，回退到 Common 的 `/api/user/self/groups` 实现，与 `fetchSiteUserGroups` 的 `/api/group/` 分页实现**是不同的端点**。

---

### 3.3 Octopus 实现

**定义位置**：`src/services/apiService/octopus/index.ts:306`  
**适用后端**：octopus

| 项目 | 说明 |
|------|------|
| **Method** | `POST` |
| **Endpoint** | `/api/v1/group/list` |
| **认证** | Octopus JWT（由 `octopusAuthManager` 管理），凭据来源为**全局用户偏好**（`userPreferences.getPreferences().octopus`），而非 `request.auth` |

> **重要**：此实现忽略 `ApiServiceRequest._request` 中的认证参数，使用从全局偏好读取的 `{ baseUrl, username, password }` 独立认证。若 Octopus 配置未就绪，返回空数组 `[]` 且不抛出错误。

**请求参数（Body）**：

Octopus 的请求体由 `fetchOctopusApi` 内部构建，通常包含 JWT token。

**响应参数**：

| 字段路径 | 类型 | 说明 |
|----------|------|------|
| `success` | `boolean` | 请求是否成功 |
| `data` | `OctopusGroup[]` | 分组列表 |
| `message` | `string` | 响应消息 |

**OctopusGroup 完整类型**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `number` | 分组 ID |
| `name` | `string` | 分组名称 |
| `mode` | `number` | 分组模式 |
| `match_regex` | `string` | 匹配正则表达式 |
| `first_token_time_out` | `number` | 首 token 超时时间 |
| `items` | `Array<{ id, group_id, channel_id, model_name, priority, weight }>` | 分组内渠道-模型映射项 |
| `items[].id` | `number` | 映射项 ID |
| `items[].group_id` | `number` | 所属分组 ID |
| `items[].channel_id` | `number` | 渠道 ID |
| `items[].model_name` | `string` | 模型名称 |
| `items[].priority` | `number` | 优先级 |
| `items[].weight` | `number` | 权重 |

**处理逻辑**：

```typescript
// 从 OctopusGroup[] 提取 name 字段作为分组标识
return (result.data || []).map((group) => group.name)
```

> 返回给调用方的是 `string[]`（分组名称列表），`OctopusGroup` 中除 `name` 外的字段均被丢弃。

**错误处理**：若 Octopus 凭据未配置或请求失败，返回 `[]`（空数组），不抛出错误。

---

### 3.4 AxonHub 实现

**定义位置**：`src/services/apiService/axonHub/index.ts:744`  
**适用后端**：axon-hub

```typescript
export async function fetchSiteUserGroups(): Promise<string[]> {
  return []
}
```

> AxonHub 不暴露 New API 的分组语义，始终返回空数组。不发送任何网络请求。此实现也不接收 `ApiServiceRequest` 参数（签名已简化）。

---

## 4. 令牌写入中的 group 字段

### 4.1 Common 实现（CreateTokenRequest.group）

**类型定义**：`src/services/apiService/common/type.ts:113`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `group` | `string` | 是 | 用户选择的分组**名称**（非 ID） |

**完整 CreateTokenRequest 字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | `string` | 是 | 密钥名称 |
| `remain_quota` | `number` | 是 | 剩余配额（0 表示不限） |
| `expired_time` | `number` | 是 | 过期时间（Unix 时间戳，秒，0 表示永不过期） |
| `unlimited_quota` | `boolean` | 是 | 是否不限配额 |
| `model_limits_enabled` | `boolean` | 是 | 是否启用模型限制 |
| `model_limits` | `string` | 是 | 模型限制配置（格式由上游定义） |
| `allow_ips` | `string` | 是 | IP 白名单（逗号分隔） |
| `group` | `string` | 是 | 分组名称 |

**Common 写入流程**：

```
用户表单提交 CreateTokenRequest.group = "vip"
  → createApiToken(request, tokenData)
  → POST/PUT /api/token/ （body 中包含 "group": "vip"）
  → 上游直接以分组名称存储
```

### 4.2 Sub2API group 转换

**适用后端**：sub2api

Sub2API 的写入端点使用 **`group_id`（数字）** 而非分组名称，因此需要将用户选择的名称解析为 ID。

**转换链路**：

```
CreateTokenRequest.group = "premium"（字符串）
  → resolveSelectedGroupId(request, "premium")
      → 重新 fetchAvailableGroupsInternal(request) 获取最新分组列表
      → resolveSub2ApiGroupId(groupsPayload, "premium", endpoint)
          → parseSub2ApiGroupList() 解析分组数组
          → find(group.name === "premium")
          → return group.id（数字）
  → translateSub2ApiCreateTokenRequest(tokenData, groupId)
      → buildSub2ApiKeyWritePayloadBase(tokenData)
          → 字段映射:
             name       → name.trim()
             quota      → unlimited_quota ? 0 : convertQuotaToUsdAmount(remain_quota)
             ip_whitelist → normalizeIpWhitelist(allow_ips)
      → withOptionalGroupId(payload, groupId)
          → payload.group_id = groupId（若 groupId 有效）
      → 添加 expires_in_days（从 expired_time 换算）
  → POST /api/v1/keys（body 使用 Sub2ApiCreateKeyPayload 格式）
```

**CreateTokenRequest → Sub2ApiCreateKeyPayload 字段映射**：

| CreateTokenRequest 字段 | Sub2ApiCreateKeyPayload 字段 | 转换规则 |
|--------------------------|------------------------------|----------|
| `name` | `name` | `tokenData.name.trim()` |
| `remain_quota` | `quota` | `unlimited_quota ? 0 : convertQuotaToUsdAmount(remain_quota)` |
| `unlimited_quota` | `quota` | `true` → quota = 0 |
| `expired_time` | `expires_in_days` | `> 0` 时换算为天数，否则为 0 |
| `allow_ips` | `ip_whitelist` | 逗号分隔字符串 → `string[]` |
| `group` | `group_id` | 名称 → 数字 ID（通过重新获取分组列表解析） |

**CreateTokenRequest → Sub2ApiUpdateKeyPayload 字段差异**（`translateSub2ApiUpdateTokenRequest`）：

| CreateTokenRequest 字段 | Sub2ApiUpdateKeyPayload 字段 | 转换规则 |
|--------------------------|------------------------------|----------|
| `expired_time` | `expires_at` | `> 0` 时转为 ISO 8601 时间戳字符串，否则为 `""` |
| — | `reset_quota` | 由额外逻辑控制 |

**解析失败错误**：若 `group` 非空但无法在最新分组列表中找到匹配的分组名称，返回错误信息（i18n key：`sub2api.groupMissing`，中文："Sub2API 分组"{group}"已不可用。请刷新分组列表后重试。"）。

---

## 5. 错误码参考

### 5.1 Common / OneHub / DoneHub （`{ success, data, message }` 信封）

| 场景 | HTTP 状态码 | success | 触发条件 | 用户操作建议 |
|------|------------|---------|----------|-------------|
| 正常响应 | 200 | `true` | — | — |
| 认证失败 | 401 | — | Cookie 过期或 token 无效 | 重新登录站点 |
| 无权限 | 403 | — | 账号权限不足 | 检查账号角色/权限配置 |
| 业务失败 | 200 | `false` | 上游返回 `success: false` | 查看 `message` 字段 |
| 服务器错误 | 5xx | — | 上游服务异常 | 稍后重试 |
| 网络错误 | — | — | fetch 抛出异常 | 检查网络连接和 baseUrl |
| 响应格式异常 | — | — | 信封解析失败 | 确认 baseUrl 指向正确的 API 端点 |

### 5.2 Sub2API （`{ code, message, data }` 信封）

| 场景 | code | HTTP 状态码 | 触发条件 | 自愈机制 | 用户操作建议 |
|------|------|------------|----------|----------|-------------|
| 正常响应 | `0` | 200 | — | — | — |
| 业务错误 | `≠ 0` | 200 | 上游业务逻辑拒绝 | 无 | 查看 `message` 字段内容 |
| JWT 过期 | — | 401 | access token 过期 | 自动用 refresh_token 续期 | 若自愈失败需重新登录 |
| Refresh token 无效 | — | 401 | refresh token 也过期或无效 | 尝试 dashboard re-sync | 需在浏览器中重新访问 Sub2API 站点 |
| 认证完全失败 | — | 401 | 所有恢复手段均失败 | 无 | 显示 login-required 提示 |

**Sub2API JWT 自愈流程**：

```
请求失败 (401)
  → 检查是否有 refreshToken
    → 有：调用 token 刷新接口获取新 JWT
      → 成功：更新存储的 auth 信息，重试原请求
      → 失败：尝试 dashboard session re-sync
        → 成功：更新 auth，重试原请求
        → 失败：抛出登录过期错误
    → 无：直接抛出认证错误
```

### 5.3 Octopus

| 场景 | 处理方式 |
|------|----------|
| 凭据未配置 | 静默返回 `[]`（`logger.warn` 记录），不抛异常 |
| 请求失败 | 静默返回 `[]`（catch 块中 `return []`），不抛异常 |

### 5.4 AxonHub

| 场景 | 处理方式 |
|------|----------|
| 任何调用 | 始终返回 `[]`，不发送网络请求 |

---

## 6. 边界情况

### 6.1 空分组列表

- **fetchUserGroups 返回 `{}`**：UI 层（`GroupSelection.tsx`）的下拉框显示空选项，表单验证要求 `group` 不为空，用户无法提交
- **Sub2API 快速创建**：`accountOperations.ts` 检测到 0 个分组 → 返回 `{ kind: "blocked" }`，阻止快速创建流程

### 6.2 单分组场景

- **Sub2API 快速创建**：检测到 1 个分组 → 返回 `{ kind: "ready", group }`，自动选择唯一定义的分组
- **表单初始化**：若 `allowedGroups` 不为空且只有 1 个有效分组，表单自动选中该分组

### 6.3 DoneHub 分页超限

- 若 DoneHub 站点的分组数超过 `100 × 100 = 10000`，`maxPages=100` 时 `fetchAllItems` 停止翻页
- 后续分组不会被加载，**可能导致部分分组缺失**（静默截断，不报错）

### 6.4 分组名称（symbol）冲突

- **DoneHub**：`fetchSiteUserGroups` 在提取 `symbol` 后通过 `new Set()` 去重
- 若两个不同分组具有相同的 `symbol`，去重后只保留一个
- 其他后端无去重处理（依赖上游保证名称唯一性）

### 6.5 Sub2API rates 中 groupId 不匹配

- `buildSub2ApiUserGroups` 在 `rates` 表中按 `String(groupId)` 查找倍率
- 若 `rates` 中无对应 key → 回退到 `group.rate_multiplier`
- 若 `rate_multiplier` 也为 null/undefined/NaN → 回退到 `1`
- 不抛出错误，以默认倍率 1 继续

### 6.6 Sub2API 写入时分组已被删除

- 创建/更新密钥时，`resolveSelectedGroupId` 重新获取分组列表（`fetchAvailableGroupsInternal`）
- 若用户之前选择的分组在此期间被上游删除：
  - `group` 非空 → 抛出错误，提示分组不可用（`sub2api.groupMissing`）
  - `group` 为空 → `resolveSelectedGroupId` 返回 `undefined`，`withOptionalGroupId` 不附加 `group_id`，密钥以无分组状态写入

### 6.7 Octopus 凭据缺失

- `fetchSiteUserGroups` 检测到 `baseUrl`/`username`/`password` 任一缺失 → 返回 `[]`，不抛异常
- 记录 warn 级别日志：`"Octopus config not available, returning empty groups"`
- 消费端（如渠道编辑中的分组下拉框）显示为空列表
