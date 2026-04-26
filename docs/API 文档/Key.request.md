# 密钥管理 API 文档

> 本文档描述 All API Hub 浏览器扩展中各后端家族的密钥管理 API 端点，涵盖请求参数、响应结构、认证方式、错误处理和站点差异。

---

## 目录

- [概述](#概述)
- [Quota 单位换算](#quota-单位换算)
- [通用类型定义](#通用类型定义)
- [认证说明](#认证说明)
- [Common 层端点（One API 家族通用）](#common-层端点one-api-家族通用)
  - [获取令牌列表](#1-获取令牌列表)
  - [获取单个令牌详情](#2-获取单个令牌详情)
  - [创建令牌](#3-创建令牌)
  - [更新令牌](#4-更新令牌)
  - [删除令牌](#5-删除令牌)
  - [解析掩码密钥](#6-解析掩码密钥)
  - [获取用户可用模型列表](#7-获取用户可用模型列表)
  - [获取用户分组信息](#8-获取用户分组信息)
  - [获取站点全部分组](#9-获取站点全部分组)
  - [获取模型定价信息](#10-获取模型定价信息)
- [OneHub 差异端点](#onehub-差异端点)
  - [OneHub 获取令牌列表](#onehub-获取令牌列表)
  - [OneHub 获取分组信息](#onehub-获取分组信息)
- [Sub2API 端点](#sub2api-端点)
  - [Sub2API 认证](#sub2api-认证)
  - [Sub2API 刷新令牌](#sub2api-刷新令牌)
  - [Sub2API 获取当前用户](#sub2api-获取当前用户)
  - [Sub2API 获取密钥列表](#sub2api-获取密钥列表)
  - [Sub2API 获取密钥详情](#sub2api-获取密钥详情)
  - [Sub2API 创建密钥](#sub2api-创建密钥)
  - [Sub2API 更新密钥](#sub2api-更新密钥)
  - [Sub2API 删除密钥](#sub2api-删除密钥)
  - [Sub2API 获取可用分组](#sub2api-获取可用分组)
  - [Sub2API 获取分组费率](#sub2api-获取分组费率)
- [Octopus 通道管理端点](#octopus-通道管理端点)
  - [Octopus 用户登录](#octopus-用户登录)
  - [Octopus 获取通道列表](#octopus-获取通道列表)
  - [Octopus 创建通道](#octopus-创建通道)
  - [Octopus 更新通道](#octopus-更新通道)
  - [Octopus 删除通道](#octopus-删除通道)
- [WONG 差异说明](#wong-差异说明)
- [站点兼容性对照表](#站点兼容性对照表)

---

## 概述

All API Hub 支持多种后端家族，各家族的密钥管理 API 存在差异：

| 后端家族 | 密钥管理模式 | API 路径前缀 | 认证方式 |
|---------|------------|------------|---------|
| One API / New API / Veloera / DoneHub | 令牌 CRUD | `/api/token/` | Cookie / AccessToken |
| OneHub | 令牌 CRUD（分页格式不同） | `/api/token/` | Cookie / Session Cookie |
| Sub2API | 密钥 CRUD（USD 额度体系） | `/api/v1/keys` | JWT + Refresh Token |
| Octopus | 通道管理（密钥内嵌于通道） | `/api/v1/channel/` | JWT（用户名密码登录） |
| WONG | 令牌 CRUD（密钥解析用 GET） | `/api/token/` | Cookie / AccessToken |

## Quota 单位换算

Common 层和 Sub2API 使用不同的额度单位体系：

| 常量 | 值 | 说明 |
|------|---|------|
| `CONVERSION_FACTOR` | `500000` | 1 USD = 500000 内部 quota 单位 |
| `DEFAULT_EXCHANGE_RATE` | `7.2` | CNY/USD 默认汇率 |

**换算公式：**

```
quota = USD × CONVERSION_FACTOR       // USD → 内部 quota
USD   = quota ÷ CONVERSION_FACTOR     // 内部 quota → USD
```

**示例：**

- `remain_quota: 5000000` → 剩余额度 10 USD
- `remain_quota: 0` + `unlimited_quota: true` → 无限额度
- Sub2API 的 `quota` 字段直接使用 USD，自动转换后映射到 `ApiToken.remain_quota`

---

## 通用类型定义

### ApiToken

令牌/密钥的核心数据结构，所有后端家族最终统一转换为此类型。

```typescript
interface ApiToken {
  id: number                       // 令牌唯一标识符
  user_id: number                  // 所属用户 ID
  key: string                      // API 密钥（可能被掩码处理，如 sk-****xxxx）
  status: number                   // 状态：1 = 已启用，0 = 已禁用
  name: string                     // 令牌显示名称
  note?: string                    // 可选备注信息
  created_time: number             // 创建时间（Unix 秒）
  accessed_time: number            // 最近访问时间（Unix 秒）
  expired_time: number             // 过期时间（Unix 秒），-1 表示永不过期
  remain_quota: number             // 剩余额度（内部 quota 单位），-1 表示无限
  unlimited_quota: boolean         // 是否无限额度
  used_quota: number               // 已使用额度（内部 quota 单位）
  model_limits_enabled?: boolean   // 是否启用模型限制
  model_limits?: string            // 允许的模型列表（逗号分隔）
  allow_ips?: string               // IP 白名单（逗号分隔）
  group?: string                   // 所属分组名称
  models?: string                  // 模型限制（部分后端使用此字段替代 model_limits）
  DeletedAt?: null                 // 软删除时间（null 表示未删除）
}
```

> **注意：** `key` 字段在列表 API 中通常返回掩码值（中间部分用 `*` 替代）。获取完整密钥需调用[解析掩码密钥端点](#6-解析掩码密钥)。所有密钥在扩展内部统一添加 `sk-` 前缀。

### CreateTokenRequest

创建和更新令牌的请求参数（Common 层通用）。

```typescript
interface CreateTokenRequest {
  name: string                     // 令牌名称
  remain_quota: number             // 剩余额度（内部 quota 单位）
  expired_time: number             // 过期时间（Unix 秒），-1 表示永不过期
  unlimited_quota: boolean         // 是否无限额度
  model_limits_enabled: boolean    // 是否启用模型限制
  model_limits: string             // 允许的模型列表（逗号分隔）
  allow_ips: string                // IP 白名单（逗号分隔）
  group: string                    // 所属分组名称
}
```

### ApiResponse

Common 层通用响应包装。

```typescript
interface ApiResponse<T = any> {
  success: boolean                 // 操作是否成功
  data: T                          // 响应数据
  message: string                  // 消息（成功或错误描述）
}
```

### PaginatedData

分页数据结构（Common 层标准格式）。

```typescript
interface PaginatedData<T> {
  page: number                     // 当前页码
  page_size: number                // 每页数量
  total: number                    // 总记录数
  items: T[]                       // 数据列表
}
```

### AuthConfig

统一认证配置结构。

```typescript
interface AuthConfig {
  authType: AuthTypeEnum            // 认证类型：cookie | access_token | none
  cookie?: string                   // Cookie 字符串（cookie 认证时使用）
  accessToken?: string              // 访问令牌（access_token 认证时使用）
  userId?: number | string          // 用户 ID
  refreshToken?: string             // Sub2API 专用的 refresh token
  tokenExpiresAt?: number           // Sub2API 专用的令牌过期时间（毫秒时间戳）
}
```

```typescript
enum AuthTypeEnum {
  AccessToken = "access_token",
  Cookie = "cookie",
  None = "none",
}
```

---

## 认证说明

### Common 认证（One API / New API / Veloera / DoneHub / WONG）

支持两种认证模式，通过 `AuthConfig.authType` 区分：

**Cookie 模式** (`authType: "cookie"`)

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `All-API-Hub-Cookie-Auth` | `cookie` | 认证方式标识 |
| `Cookie` | `{cookie}` | 认证 Cookie |
| `All-API-Hub-Session-Cookie` | `{cookie}` | Firefox Cookie 拦截器使用 |

**AccessToken 模式** (`authType: "access_token"`)

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `All-API-Hub-Cookie-Auth` | `token` | 认证方式标识 |
| `Authorization` | `Bearer {accessToken}` | 认证令牌 |

**兼容性用户 ID 请求头**（两种模式通用，扩展自动将 `userId` 扇出至所有兼容头）：

| 请求头 | 值 | 说明 |
|-------|---|------|
| `New-API-User` | `{userId}` | New API 兼容头 |
| `Veloera-User` | `{userId}` | Veloera 兼容头 |
| `voapi-user` | `{userId}` | VoAPI 兼容头 |
| `User-id` | `{userId}` | 通用用户 ID 头 |
| `Rix-Api-User` | `{userId}` | Rix API 兼容头 |
| `neo-api-user` | `{userId}` | Neo API 兼容头 |

### OneHub 认证

与 Common 认证相同，但额外支持 **Session Cookie** 模式。当使用 Cookie 认证时，OneHub 会利用浏览器 Session Cookie 进行身份验证。

### Sub2API 认证

Sub2API 使用 **JWT + Refresh Token** 双令牌机制，并实现三层恢复策略：

1. **JWT 补水（Hydration）**：从账号存储中读取已有的 `accessToken` 和 `refreshToken`
2. **主动刷新（Proactive Refresh）**：在令牌过期前 2 分钟（120 秒缓冲）自动刷新
3. **被动恢复（Reactive Recovery）**：遇到 401 错误时依次尝试：
   - a. 使用 Refresh Token 刷新
   - b. 从浏览器 localStorage 重新同步 JWT（`localStorage.auth_token`）
   - c. 以上均失败则抛出登录要求

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

### Octopus 认证

Octopus 使用 **用户名/密码登录** 获取 JWT，具有以下特点：

- JWT 仅缓存在内存中（不持久化），默认有效期 15 分钟
- 过期前 1 分钟自动重新登录获取新令牌
- 缓存键为 `{baseUrl}:{username}`

---

## Common 层端点（One API 家族通用）

> 适用于：One API、New API、Veloera、DoneHub 等兼容后端。

### 1. 获取令牌列表

获取当前账号下的所有 API 令牌。

**请求**

```
GET /api/token/?p={page}&size={size}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Query 参数**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `p` | `number` | 否 | `0` | 页码（从 0 开始） |
| `size` | `number` | 否 | `100` | 每页数量 |

**成功响应** `200 OK`

响应可能为以下两种格式之一：

**格式 A：直接数组**

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "user_id": 1,
      "key": "sk-****abcd",
      "status": 1,
      "name": "默认令牌",
      "note": "用于开发环境",
      "created_time": 1700000000,
      "accessed_time": 1700086400,
      "expired_time": -1,
      "remain_quota": -1,
      "unlimited_quota": true,
      "used_quota": 2500000,
      "model_limits_enabled": false,
      "model_limits": "",
      "allow_ips": "",
      "group": "default"
    },
    {
      "id": 2,
      "user_id": 1,
      "key": "sk-****efgh",
      "status": 1,
      "name": "测试令牌",
      "created_time": 1700000000,
      "accessed_time": 0,
      "expired_time": 1735689600,
      "remain_quota": 5000000,
      "unlimited_quota": false,
      "used_quota": 0,
      "model_limits_enabled": true,
      "model_limits": "gpt-4,gpt-4o",
      "allow_ips": "192.168.1.0/24",
      "group": "vip"
    }
  ],
  "message": ""
}
```

**格式 B：分页对象**

```json
{
  "success": true,
  "data": {
    "page": 0,
    "page_size": 100,
    "total": 2,
    "items": [
      {
        "id": 1,
        "user_id": 1,
        "key": "sk-****abcd",
        "status": 1,
        "name": "默认令牌",
        "created_time": 1700000000,
        "accessed_time": 1700086400,
        "expired_time": -1,
        "remain_quota": -1,
        "unlimited_quota": true,
        "used_quota": 2500000,
        "model_limits_enabled": false,
        "model_limits": "",
        "allow_ips": "",
        "group": "default"
      }
    ]
  },
  "message": ""
}
```

**错误响应**

| HTTP 状态码 | 错误码 | 说明 |
|------------|--------|------|
| `401` | `HTTP_401` | 未认证或认证信息无效 |
| `403` | `HTTP_403` | 无权限访问 |
| `429` | `HTTP_429` | 请求频率过高 |

```json
{
  "success": false,
  "message": "请求失败: 401",
  "data": null
}
```

> **注意：** 扩展会自动对返回的 `key` 字段添加 `sk-` 前缀规范化处理。

---

### 2. 获取单个令牌详情

根据令牌 ID 获取详细信息。

**请求**

```
GET /api/token/{tokenId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 令牌 ID |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": 1,
    "user_id": 1,
    "key": "sk-****abcd",
    "status": 1,
    "name": "默认令牌",
    "note": "用于开发环境",
    "created_time": 1700000000,
    "accessed_time": 1700086400,
    "expired_time": -1,
    "remain_quota": -1,
    "unlimited_quota": true,
    "used_quota": 2500000,
    "model_limits_enabled": false,
    "model_limits": "",
    "allow_ips": "",
    "group": "default",
    "DeletedAt": null
  },
  "message": ""
}
```

**错误响应**

| HTTP 状态码 | 错误码 | 说明 |
|------------|--------|------|
| `401` | `HTTP_401` | 未认证 |
| `403` | `HTTP_403` | 无权限 |

```json
{
  "success": false,
  "message": "请求失败: 401",
  "data": null
}
```

---

### 3. 创建令牌

创建一个新的 API 令牌。

**请求**

```
POST /api/token/
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Request Body**

```json
{
  "name": "新令牌",
  "remain_quota": 5000000,
  "expired_time": -1,
  "unlimited_quota": false,
  "model_limits_enabled": true,
  "model_limits": "gpt-4,gpt-4o",
  "allow_ips": "",
  "group": "default"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | `string` | 是 | 令牌名称 |
| `remain_quota` | `number` | 是 | 剩余额度（内部 quota 单位）。`0` 表示不限制额度 |
| `expired_time` | `number` | 是 | 过期时间（Unix 秒）。`-1` 表示永不过期 |
| `unlimited_quota` | `boolean` | 是 | 是否无限额度。`true` 时 `remain_quota` 被忽略 |
| `model_limits_enabled` | `boolean` | 是 | 是否启用模型限制 |
| `model_limits` | `string` | 是 | 允许的模型列表（逗号分隔）。空字符串表示不限制 |
| `allow_ips` | `string` | 是 | IP 白名单（逗号分隔）。空字符串表示不限制 |
| `group` | `string` | 是 | 所属分组名称。空字符串表示使用用户默认分组 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "message": "",
  "data": null
}
```

> **注意：** 创建响应不包含 `data` 字段中的令牌信息，仅通过 `success: true` 确认创建成功。

**错误响应**

```json
{
  "success": false,
  "message": "令牌名称已存在",
  "data": null
}
```

---

### 4. 更新令牌

更新现有令牌的属性。请求体包含原始 `CreateTokenRequest` 加上令牌 `id`。

**请求**

```
PUT /api/token/
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Request Body**

```json
{
  "id": 1,
  "name": "更新后的令牌",
  "remain_quota": 10000000,
  "expired_time": 1735689600,
  "unlimited_quota": false,
  "model_limits_enabled": false,
  "model_limits": "",
  "allow_ips": "10.0.0.0/8",
  "group": "vip"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `number` | 是 | 要更新的令牌 ID |
| `name` | `string` | 是 | 令牌名称 |
| `remain_quota` | `number` | 是 | 剩余额度（内部 quota 单位） |
| `expired_time` | `number` | 是 | 过期时间（Unix 秒）。`-1` 表示永不过期 |
| `unlimited_quota` | `boolean` | 是 | 是否无限额度 |
| `model_limits_enabled` | `boolean` | 是 | 是否启用模型限制 |
| `model_limits` | `string` | 是 | 允许的模型列表（逗号分隔） |
| `allow_ips` | `string` | 是 | IP 白名单（逗号分隔） |
| `group` | `string` | 是 | 所属分组名称 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "message": "",
  "data": null
}
```

**错误响应**

```json
{
  "success": false,
  "message": "更新令牌失败",
  "data": null
}
```

---

### 5. 删除令牌

永久删除指定的 API 令牌。

**请求**

```
DELETE /api/token/{tokenId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 要删除的令牌 ID |

**成功响应** `200 OK`

```json
{
  "success": true,
  "message": "",
  "data": null
}
```

**错误响应**

```json
{
  "success": false,
  "message": "删除令牌失败",
  "data": null
}
```

---

### 6. 解析掩码密钥

获取令牌的完整未掩码密钥。当列表 API 返回的 `key` 字段包含 `*` 时，需通过此端点获取完整密钥。

**请求**

```
POST /api/token/{tokenId}/key
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 令牌 ID |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": {
    "key": "sk-abcdefghijklmnopqrstuvwxyz1234567890"
  },
  "message": ""
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `key` | `string` | 完整的未掩码 API 密钥（自动添加 `sk-` 前缀） |

> **注意：** 扩展会自动对返回的 `key` 添加 `sk-` 前缀规范化处理。解析结果会被缓存在内存中，令牌 CRUD 操作时自动清除缓存。

**错误响应**

```json
{
  "success": false,
  "message": "令牌不存在",
  "data": null
}
```

> **站点差异：** WONG 后端使用 `GET` 方法而非 `POST`，详见 [WONG 差异说明](#wong-差异说明)。

---

### 7. 获取用户可用模型列表

获取当前账号可以使用的模型标识符列表。

**请求**

```
GET /api/user/models
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": [
    "gpt-4",
    "gpt-4o",
    "gpt-4o-mini",
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229"
  ],
  "message": ""
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data` | `string[]` | 可用模型标识符数组 |

> **站点差异：** Sub2API 不提供此端点，返回空数组。Octopus 使用 `GET /api/v1/model/list`。

**错误响应**

```json
{
  "success": false,
  "message": "获取模型列表失败",
  "data": null
}
```

---

### 8. 获取用户分组信息

获取当前用户所属的分组及其权限信息。

**请求**

```
GET /api/user/self/groups
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": {
    "default": {
      "desc": "默认分组",
      "ratio": 1.0
    },
    "vip": {
      "desc": "VIP 分组",
      "ratio": 0.8
    }
  },
  "message": ""
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data` | `Record<string, UserGroupInfo>` | 分组名称到分组信息的映射 |
| `data.{group}.desc` | `string` | 分组描述 |
| `data.{group}.ratio` | `number` | 分组倍率（影响计费） |

> **站点差异：** OneHub 使用 `GET /api/user_group_map` 端点，详见 [OneHub 获取分组信息](#onehub-获取分组信息)。Sub2API 使用组合请求，详见 [Sub2API 获取可用分组](#sub2api-获取可用分组)。

**错误响应**

```json
{
  "success": false,
  "message": "获取分组信息失败",
  "data": null
}
```

---

### 9. 获取站点全部分组

获取站点上定义的所有用户分组标识符（管理用途）。

**请求**

```
GET /api/group
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": ["default", "vip", "premium"],
  "message": ""
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data` | `string[]` | 站点全部分组标识符数组 |

**错误响应**

```json
{
  "success": false,
  "message": "获取站点分组信息失败",
  "data": null
}
```

---

### 10. 获取模型定价信息

获取当前账号可用的模型定价元数据。

**请求**

```
GET /api/pricing
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie 认证时 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "model_name": "gpt-4",
      "model_description": "GPT-4",
      "quota_type": 0,
      "model_ratio": 15,
      "model_price": 0.03,
      "owner_by": "openai",
      "completion_ratio": 2,
      "enable_groups": ["default", "vip"],
      "supported_endpoint_types": ["openai"]
    }
  ],
  "group_ratio": {
    "default": 1.0,
    "vip": 0.8
  },
  "usable_group": {
    "default": "默认分组",
    "vip": "VIP 分组"
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data` | `ModelPricing[]` | 模型定价信息数组 |
| `data[].model_name` | `string` | 模型标识符 |
| `data[].model_description` | `string?` | 模型描述 |
| `data[].quota_type` | `number` | 计费类型：`0` = 按量计费，`1` = 按次计费 |
| `data[].model_ratio` | `number` | 模型倍率 |
| `data[].model_price` | `number \| PerCallPrice` | 模型价格 |
| `data[].owner_by` | `string?` | 模型所有者 |
| `data[].completion_ratio` | `number` | 补全倍率 |
| `data[].enable_groups` | `string[]` | 启用此模型的分组列表 |
| `data[].supported_endpoint_types` | `string[]` | 支持的端点类型 |
| `group_ratio` | `Record<string, number>` | 分组倍率映射 |
| `usable_group` | `Record<string, string>` | 可用分组映射（名称 → 描述） |

> **站点差异：** OneHub 使用不同的定价结构，详见 [OneHub 差异](#onehub-差异端点)。

**错误响应**

```json
{
  "success": false,
  "message": "获取模型定价失败",
  "data": null
}
```

---

## OneHub 差异端点

> OneHub 是 One API 的下游分支，大部分 API 复用 Common 层，但以下端点存在差异。

### OneHub 获取令牌列表

OneHub 使用不同的分页响应格式。

**请求**

```
GET /api/token/?p={page}&size={size}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie / Session Cookie 认证时 |

**Query 参数**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `p` | `number` | 否 | `0` | 页码（从 0 开始） |
| `size` | `number` | 否 | `100` | 每页数量 |

**成功响应** `200 OK`

**OneHub 特有格式（`data` 字段而非 `items`）**：

```json
{
  "success": true,
  "data": {
    "data": [
      {
        "id": 1,
        "user_id": 1,
        "key": "sk-****abcd",
        "status": 1,
        "name": "默认令牌",
        "created_time": 1700000000,
        "accessed_time": 1700086400,
        "expired_time": -1,
        "remain_quota": -1,
        "unlimited_quota": true,
        "used_quota": 2500000,
        "group": "default",
        "setting": {
          "heartbeat": {
            "enabled": true,
            "timeout_seconds": 30
          }
        }
      }
    ],
    "page": 0,
    "size": 100,
    "total_count": 1
  },
  "message": ""
}
```

**与 Common 层的差异**：

| 项目 | Common 层 | OneHub |
|------|----------|--------|
| 数据字段名 | `items` | `data` |
| 分页结构 | `{ page, page_size, total, items }` | `{ data, page, size, total_count }` |
| Token 额外字段 | 无 | `setting.heartbeat`（心跳配置） |

**OneHub 特有字段**：

```typescript
interface OneHubApiToken extends ApiToken {
  setting?: {
    heartbeat?: {
      enabled: boolean         // 是否启用心跳检测
      timeout_seconds: number  // 心跳超时时间（秒）
    }
  }
}
```

---

### OneHub 获取分组信息

OneHub 使用独立的分组映射端点。

**请求**

```
GET /api/user_group_map
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Pragma` | `no-cache` | 禁用缓存 |
| `Authorization` | `Bearer {token}` | AccessToken 认证时 |
| `Cookie` | `{cookie}` | Cookie / Session Cookie 认证时 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": {
    "default": {
      "id": 1,
      "symbol": "default",
      "name": "默认分组",
      "ratio": 1.0,
      "api_rate": 60,
      "public": true,
      "promotion": false,
      "min": 0,
      "max": 0,
      "enable": true
    },
    "vip": {
      "id": 2,
      "symbol": "vip",
      "name": "VIP 分组",
      "ratio": 0.8,
      "api_rate": 120,
      "public": false,
      "promotion": true,
      "min": 100,
      "max": 0,
      "enable": true
    }
  },
  "message": ""
}
```

**OneHub 分组类型**：

```typescript
interface OneHubUserGroupInfo {
  id: number               // 分组 ID
  symbol: string           // 分组标识符
  name: string             // 分组显示名称
  ratio: number            // 分组倍率
  api_rate: number         // API 调用频率限制（次/分钟）
  public: boolean          // 是否公开分组
  promotion: boolean       // 是否促销分组
  min: number              // 最低充值要求
  max: number              // 最高充值限制（0 = 无限制）
  enable: boolean          // 是否启用
}
```

扩展内部会将其转换为通用 `UserGroupInfo` 格式（仅保留 `desc` 和 `ratio`）。

---

## Sub2API 端点

> Sub2API 是一个独立的后端家族，使用完全不同的 API 路径（`/api/v1/*`）和响应格式（`{code, message, data}` 信封）。采用 USD 额度体系，通过 JWT + Refresh Token 进行认证。

### Sub2API 认证

Sub2API 的所有密钥管理端点都要求 JWT 认证。JWT 通过登录流程获取，并通过 Refresh Token 机制自动续期。

**认证流程**：

```
用户登录 → 获取 JWT + Refresh Token
         ↓
令牌过期前 2 分钟 → POST /api/v1/auth/refresh（自动续期）
         ↓
401 错误 → 尝试 Refresh → 失败则从 localStorage 重新同步
```

**通用请求头**（Sub2API 所有端点）：

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求/响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌（必须） |

**通用响应格式（Sub2API 信封）**：

```typescript
interface Sub2ApiEnvelope<T> {
  code: number           // 0 表示成功，非 0 表示业务错误
  message: string        // 响应消息
  data?: T               // 响应数据
}
```

---

### Sub2API 刷新令牌

刷新即将过期或已过期的 JWT 访问令牌。

**请求**

```
POST /api/v1/auth/refresh
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {currentJwt}` | 当前 JWT（如有） |

**Request Body**

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `refresh_token` | `string` | 是 | Refresh Token |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.new_payload",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.new_refresh",
    "expires_in": 3600
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data.access_token` | `string` | 新的 JWT 访问令牌 |
| `data.refresh_token` | `string` | 新的 Refresh Token（令牌轮换） |
| `data.expires_in` | `number` | 过期时间（秒） |

> **注意：** 扩展在刷新成功后会自动更新内存中的令牌和账号存储中的持久化信息。刷新缓冲时间为 120 秒（即过期前 2 分钟触发刷新）。

**错误响应**

```json
{
  "code": 1,
  "message": "Invalid refresh token",
  "data": null
}
```

当 `code` 非 0 时，扩展视为刷新失败并触发三层恢复策略中的下一步。

---

### Sub2API 获取当前用户

获取当前 JWT 对应的用户信息，包括余额。

**请求**

```
GET /api/v1/auth/me
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |
| `Cache` | `no-store` | 禁用缓存 |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "username": "testuser",
    "email": "test@example.com",
    "balance": 25.50
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data.id` | `number \| string` | 用户 ID |
| `data.username` | `string \| null` | 用户名 |
| `data.email` | `string \| null` | 邮箱地址 |
| `data.balance` | `number \| string \| null` | 余额（USD） |

> **转换规则：** `balance`（USD）会通过 `balance × 500000` 转换为内部 quota 单位。显示名称优先使用 `username`，为空时使用 `email` 的 `@` 前部分。

---

### Sub2API 获取密钥列表

获取当前账号的所有 API 密钥。

**请求**

```
GET /api/v1/keys?page={page}&page_size={size}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |
| `Cache` | `no-store` | 禁用缓存 |

**Query 参数**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `page` | `number` | 否 | `1` | 页码（从 **1** 开始，注意与 Common 层的从 0 开始不同） |
| `page_size` | `number` | 否 | `100` | 每页数量 |

**成功响应** `200 OK`

**格式 A：分页对象**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "id": 1,
        "user_id": 1,
        "key": "sk-abc123def456",
        "name": "默认密钥",
        "status": "active",
        "quota": 10.0,
        "quota_used": 2.5,
        "expires_at": "2025-12-31T23:59:59Z",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-06-15T12:00:00Z",
        "ip_whitelist": ["192.168.1.0/24"],
        "group_id": 1,
        "group": {
          "id": 1,
          "name": "default",
          "description": "默认分组",
          "rate_multiplier": 1.0
        }
      }
    ],
    "total": 1,
    "page": 1,
    "page_size": 100,
    "pages": 1
  }
}
```

**格式 B：直接数组**

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 1,
      "user_id": 1,
      "key": "sk-abc123def456",
      "name": "默认密钥",
      "status": "active",
      "quota": 10.0,
      "quota_used": 2.5,
      "expires_at": "2025-12-31T23:59:59Z",
      "group_id": 1,
      "group": {
        "id": 1,
        "name": "default"
      }
    }
  ]
}
```

**Sub2API 密钥原始类型**：

```typescript
interface Sub2ApiKeyData {
  id: number | string                     // 密钥 ID
  user_id?: number | string | null        // 用户 ID
  key?: string | null                      // API 密钥（可能为完整值）
  name?: string | null                     // 密钥名称
  status?: "active" | "inactive" | "quota_exhausted" | "expired" | number | null
  quota?: number | string | null           // 总额度（USD）
  quota_used?: number | string | null      // 已用额度（USD）
  expires_at?: string | number | null      // 过期时间（ISO 8601 或 Unix 时间戳）
  created_at?: string | number | null      // 创建时间
  updated_at?: string | number | null      // 更新时间
  ip_whitelist?: string[] | string | null  // IP 白名单
  group_id?: number | string | null        // 分组 ID
  group?: Sub2ApiGroupData | null          // 关联分组对象
  Group?: Sub2ApiGroupData | null          // 兼容大写 Group 字段
}
```

**Sub2API 分组类型**：

```typescript
interface Sub2ApiGroupData {
  id: number | string              // 分组 ID
  name?: string | null             // 分组名称
  description?: string | null      // 分组描述
  rate_multiplier?: number | null  // 费率倍数
}
```

> **转换规则：** Sub2API 的密钥数据会被转换为统一的 `ApiToken` 格式。`status` 字符串映射为数字（`active` → `1`，其他 → `0`）。额度从 USD 转换为内部 quota 单位（`USD × 500000`）。

---

### Sub2API 获取密钥详情

获取单个密钥的详细信息。

**请求**

```
GET /api/v1/keys/{tokenId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |
| `Cache` | `no-store` | 禁用缓存 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 密钥 ID |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "id": 1,
    "user_id": 1,
    "key": "sk-abc123def456",
    "name": "默认密钥",
    "status": "active",
    "quota": 10.0,
    "quota_used": 2.5,
    "expires_at": "2025-12-31T23:59:59Z",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-06-15T12:00:00Z",
    "ip_whitelist": ["192.168.1.0/24"],
    "group_id": 1,
    "group": {
      "id": 1,
      "name": "default",
      "description": "默认分组",
      "rate_multiplier": 1.0
    }
  }
}
```

---

### Sub2API 创建密钥

创建新的 API 密钥。请求体与 Common 层不同，使用 USD 额度和 `expires_in_days` 字段。

**请求**

```
POST /api/v1/keys
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Request Body（扩展内部转换后发送）**

扩展接收 Common 层的 `CreateTokenRequest`，内部自动转换为 Sub2API 格式：

```json
{
  "name": "新密钥",
  "group_id": 1,
  "quota": 10.0,
  "ip_whitelist": ["192.168.1.0/24"],
  "expires_in_days": 365
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | `string` | 是 | 密钥名称 |
| `group_id` | `number` | 否 | 分组 ID（从分组名称自动解析） |
| `quota` | `number` | 否 | 额度（USD）。`0` 表示无限额度 |
| `ip_whitelist` | `string[]` | 否 | IP 白名单数组 |
| `expires_in_days` | `number` | 否 | 有效天数。`0` 表示永不过期 |

> **转换逻辑：**
> - `CreateTokenRequest.remain_quota`（内部单位）÷ 500000 → `quota`（USD）
> - `CreateTokenRequest.unlimited_quota: true` → `quota: 0`
> - `CreateTokenRequest.expired_time`（Unix 秒）→ `expires_in_days`（距今天数，向上取整）
> - `CreateTokenRequest.group`（分组名称）→ `group_id`（通过 `/api/v1/groups/available` 解析）

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": null
}
```

**错误响应**

```json
{
  "code": 1,
  "message": "Group not found: nonexistent_group",
  "data": null
}
```

---

### Sub2API 更新密钥

更新现有密钥。与创建类似，但使用 `expires_at`（ISO 时间戳）而非 `expires_in_days`。

**请求**

```
PUT /api/v1/keys/{tokenId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 密钥 ID |

**Request Body（扩展内部转换后发送）**

```json
{
  "name": "更新后的密钥",
  "group_id": 2,
  "quota": 15.0,
  "ip_whitelist": [],
  "expires_at": "2025-12-31T23:59:59Z",
  "status": "active",
  "reset_quota": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | `string` | 是 | 密钥名称 |
| `group_id` | `number` | 否 | 分组 ID |
| `quota` | `number` | 否 | 总额度（USD），包含已用部分 |
| `ip_whitelist` | `string[]` | 否 | IP 白名单数组 |
| `expires_at` | `string` | 否 | 过期时间（ISO 8601 格式），空字符串表示永不过期 |
| `status` | `"active" \| "inactive"` | 否 | 密钥状态 |
| `reset_quota` | `boolean` | 否 | 是否重置已用额度 |

> **转换逻辑：**
> - `CreateTokenRequest.remain_quota` → `quota`（USD），且会加上已用额度
> - `CreateTokenRequest.unlimited_quota: true` → `quota: 0`
> - `CreateTokenRequest.expired_time`（Unix 秒）→ `expires_at`（ISO 8601）
> - 更新前会先获取现有密钥信息，以确保 `remain_quota` 转换正确

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": null
}
```

---

### Sub2API 删除密钥

删除指定的 API 密钥。

**请求**

```
DELETE /api/v1/keys/{tokenId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `tokenId` | `number` | 是 | 密钥 ID |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": null
}
```

> **注意：** Sub2API 删除响应允许 `data` 为空（`allowMissingData: true`）。

---

### Sub2API 获取可用分组

获取 Sub2API 站点上所有可用的分组列表。

**请求**

```
GET /api/v1/groups/available
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |
| `Cache` | `no-store` | 禁用缓存 |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": [
    {
      "id": 1,
      "name": "default",
      "description": "默认分组",
      "rate_multiplier": 1.0
    },
    {
      "id": 2,
      "name": "premium",
      "description": "高级分组",
      "rate_multiplier": 0.8
    }
  ]
}
```

---

### Sub2API 获取分组费率

获取各分组的费率信息。

**请求**

```
GET /api/v1/groups/rates
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |
| `Cache` | `no-store` | 禁用缓存 |

**成功响应** `200 OK`

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "1": 1.0,
    "2": 0.8
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data` | `Record<string, number>` | 分组 ID 到费率的映射 |

> **合并逻辑：** 扩展会将 `groups/available` 和 `groups/rates` 两个端点的结果合并，转换为通用的 `Record<string, UserGroupInfo>` 格式。`rate_multiplier` 作为 `ratio` 的补充来源。

---

## Octopus 通道管理端点

> Octopus 采用完全不同的密钥管理架构：API 密钥内嵌于**通道（Channel）**对象中，不使用传统的独立令牌 CRUD。通道管理即密钥管理。

### Octopus 用户登录

通过用户名和密码获取 JWT 令牌。

**请求**

```
POST /api/v1/user/login
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |

> **注意：** 此端点不需要 `Authorization` 头。

**Request Body**

```json
{
  "username": "admin",
  "password": "your_password",
  "expire": 900
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `username` | `string` | 是 | 用户名 |
| `password` | `string` | 是 | 密码 |
| `expire` | `number` | 否 | Token 有效期（秒），后端默认 900（15 分钟） |

**成功响应** `200 OK`

> **注意：** Octopus 登录端点使用 `{code, message, data}` 信封格式（与 Sub2API 类似），成功时 `code: 200`。

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expire_at": "2024-06-15T13:00:00Z"
  }
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `data.token` | `string` | JWT 访问令牌 |
| `data.expire_at` | `string` | 令牌过期时间（ISO 8601） |

> **缓存策略：** JWT 仅缓存在内存中，不持久化。过期前 1 分钟自动重新登录获取新令牌。

**错误响应**

| HTTP 状态码 | 说明 |
|------------|------|
| `403` | 认证失败或 CORS 配置问题 |

```json
{
  "code": 403,
  "message": "Invalid credentials",
  "data": null
}
```

---

### Octopus 获取通道列表

获取所有通道，每个通道包含内嵌的 API 密钥。

**请求**

```
GET /api/v1/channel/list
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "OpenAI-GPT4",
      "type": 0,
      "enabled": true,
      "base_urls": [
        { "url": "https://api.openai.com", "delay": 120 }
      ],
      "keys": [
        {
          "id": 1,
          "channel_id": 1,
          "enabled": true,
          "channel_key": "sk-abc123...",
          "remark": "主密钥",
          "status_code": 200,
          "last_use_time_stamp": 1700086400,
          "total_cost": 5.25
        }
      ],
      "model": "gpt-4,gpt-4o",
      "custom_model": "",
      "proxy": false,
      "auto_sync": false,
      "auto_group": 0,
      "custom_header": [],
      "param_override": "",
      "channel_proxy": "",
      "match_regex": "",
      "stats": {
        "channel_id": 1,
        "input_token": 15000,
        "output_token": 5000,
        "input_cost": 0.45,
        "output_cost": 0.30,
        "wait_time": 2500,
        "request_success": 100,
        "request_failed": 2
      }
    }
  ],
  "message": ""
}
```

**通道类型枚举**：

| 值 | 名称 | 说明 |
|----|------|------|
| `0` | `OpenAIChat` | OpenAI 聊天补全 |
| `1` | `OpenAIResponse` | OpenAI 响应模式 |
| `2` | `Anthropic` | Anthropic (Claude) |
| `3` | `Gemini` | Google Gemini |
| `4` | `Volcengine` | 火山引擎 |
| `5` | `OpenAIEmbedding` | OpenAI 嵌入 |

**自动分组类型枚举**：

| 值 | 名称 | 说明 |
|----|------|------|
| `0` | `None` | 不自动分组 |
| `1` | `Fuzzy` | 模糊匹配 |
| `2` | `Exact` | 精确匹配 |
| `3` | `Regex` | 正则匹配 |

**通道密钥对象**：

```typescript
interface OctopusChannelKey {
  id?: number                    // 密钥唯一标识符
  channel_id?: number            // 所属通道 ID
  enabled: boolean               // 是否启用
  channel_key: string            // API 密钥值
  remark?: string                // 备注信息
  status_code?: number           // 最后响应状态码
  last_use_time_stamp?: number   // 最后使用时间（Unix 秒）
  total_cost?: number            // 累计消费金额
}
```

---

### Octopus 创建通道

创建新通道（同时指定内嵌的 API 密钥）。

**请求**

```
POST /api/v1/channel/create
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Request Body**

```json
{
  "name": "New-Channel",
  "type": 0,
  "enabled": true,
  "base_urls": [
    { "url": "https://api.openai.com" }
  ],
  "keys": [
    {
      "enabled": true,
      "channel_key": "sk-your-api-key-here",
      "remark": "主密钥"
    }
  ],
  "model": "gpt-4,gpt-4o",
  "custom_model": "",
  "proxy": false,
  "auto_sync": false,
  "auto_group": 0,
  "custom_header": [],
  "param_override": "",
  "channel_proxy": "",
  "match_regex": ""
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | `string` | 是 | 通道名称（必须唯一） |
| `type` | `OctopusOutboundType` | 是 | 通道类型 |
| `enabled` | `boolean` | 否 | 是否启用（默认 `true`） |
| `base_urls` | `OctopusBaseUrl[]` | 是 | 基础 URL 列表 |
| `keys` | `OctopusChannelKey[]` | 是 | API 密钥列表 |
| `model` | `string` | 否 | 支持的模型列表（逗号分隔） |
| `custom_model` | `string` | 否 | 自定义模型列表 |
| `proxy` | `boolean` | 否 | 是否使用代理 |
| `auto_sync` | `boolean` | 否 | 是否自动同步模型 |
| `auto_group` | `OctopusAutoGroupType` | 否 | 自动分组类型 |
| `custom_header` | `OctopusCustomHeader[]` | 否 | 自定义请求头 |
| `param_override` | `string` | 否 | 参数覆盖配置 |
| `channel_proxy` | `string` | 否 | 通道专用代理地址 |
| `match_regex` | `string` | 否 | 模型匹配正则 |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": null,
  "message": ""
}
```

---

### Octopus 更新通道

更新现有通道的属性，支持对内嵌密钥进行增删改操作。

**请求**

```
POST /api/v1/channel/update
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 请求体格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Request Body**

```json
{
  "id": 1,
  "name": "Updated-Channel",
  "enabled": true,
  "model": "gpt-4,gpt-4o,gpt-4o-mini",
  "base_urls": [
    { "url": "https://api.openai.com" }
  ],
  "keys_to_add": [
    {
      "enabled": true,
      "channel_key": "sk-new-backup-key",
      "remark": "备用密钥"
    }
  ],
  "keys_to_update": [
    {
      "id": 1,
      "enabled": false,
      "remark": "已禁用"
    }
  ],
  "keys_to_delete": [2, 3]
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `number` | 是 | 要更新的通道 ID |
| `name` | `string` | 否 | 新名称 |
| `type` | `OctopusOutboundType` | 否 | 新通道类型 |
| `enabled` | `boolean` | 否 | 是否启用 |
| `base_urls` | `OctopusBaseUrl[]` | 否 | 新基础 URL 列表 |
| `model` | `string` | 否 | 新模型列表 |
| `keys_to_add` | `OctopusKeyAddRequest[]` | 否 | 要添加的新密钥 |
| `keys_to_update` | `OctopusKeyUpdateRequest[]` | 否 | 要更新的密钥 |
| `keys_to_delete` | `number[]` | 否 | 要删除的密钥 ID 列表 |

**密钥添加请求**：

```typescript
interface OctopusKeyAddRequest {
  enabled?: boolean       // 是否启用（默认 true）
  channel_key: string     // API 密钥值
  remark?: string         // 备注信息
}
```

**密钥更新请求**：

```typescript
interface OctopusKeyUpdateRequest {
  id: number              // 要更新的密钥 ID
  enabled?: boolean       // 是否启用
  channel_key?: string    // 新的 API 密钥值
  remark?: string         // 新的备注信息
}
```

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": null,
  "message": ""
}
```

---

### Octopus 删除通道

永久删除指定通道及其所有内嵌密钥。

**请求**

```
DELETE /api/v1/channel/delete/{channelId}
```

**请求头**

| 请求头 | 值 | 说明 |
|-------|---|------|
| `Content-Type` | `application/json` | 响应格式 |
| `Authorization` | `Bearer {jwt}` | JWT 访问令牌 |

**Path 参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `channelId` | `number` | 是 | 通道 ID |

**成功响应** `200 OK`

```json
{
  "success": true,
  "data": null,
  "message": ""
}
```

---

## WONG 差异说明

> WONG (wong-gongyi) 后端复用 Common 层的 Token CRUD API，仅密钥解析端点的 HTTP 方法不同。

### 密钥解析方法差异

| 项目 | Common 层 | WONG |
|------|----------|------|
| 端点 | `/api/token/{tokenId}/key` | `/api/token/{tokenId}/key`（相同） |
| HTTP 方法 | `POST` | **`GET`** |

WONG 使用 `GET` 方法调用密钥解析端点，请求和响应格式与 Common 层完全相同：

```
GET /api/token/{tokenId}/key
```

**成功响应**：与 [解析掩码密钥](#6-解析掩码密钥) 相同。

---

## 站点兼容性对照表

### 令牌 CRUD 兼容性

| 端点 | Common | OneHub | Sub2API | Octopus | WONG |
|------|--------|--------|---------|---------|------|
| 获取令牌列表 | `GET /api/token/` | `GET /api/token/`（格式不同） | `GET /api/v1/keys` | 通道管理替代 | `GET /api/token/` |
| 获取令牌详情 | `GET /api/token/{id}` | 复用 Common | `GET /api/v1/keys/{id}` | 通道管理替代 | 复用 Common |
| 创建令牌 | `POST /api/token/` | 复用 Common | `POST /api/v1/keys` | 通道管理替代 | 复用 Common |
| 更新令牌 | `PUT /api/token/` | 复用 Common | `PUT /api/v1/keys/{id}` | 通道管理替代 | 复用 Common |
| 删除令牌 | `DELETE /api/token/{id}` | 复用 Common | `DELETE /api/v1/keys/{id}` | 通道管理替代 | 复用 Common |
| 解析掩码密钥 | `POST /api/token/{id}/key` | 复用 Common | 不需要（返回完整密钥） | 不适用 | **`GET`** `/api/token/{id}/key` |

### 响应格式差异

| 项目 | Common | OneHub | Sub2API | Octopus |
|------|--------|--------|---------|---------|
| 响应信封 | `{success, data, message}` | `{success, data, message}` | `{code, message, data}` | 登录：`{code, message, data}`；通道：`{success, data, message}` |
| 成功标识 | `success: true` | `success: true` | `code: 0` | 登录：`code: 200`；通道：`success: true` |
| 分页数据字段 | `items` | **`data`** | `items` | 不适用 |
| 分页元数据 | `{page, page_size, total}` | `{page, size, total_count}` | `{page, page_size, total, pages}` | 不适用 |

### 认证方式差异

| 后端 | Cookie | AccessToken | JWT | Refresh Token | 用户名密码 |
|------|--------|------------|-----|---------------|----------|
| Common | ✅ | ✅ | - | - | - |
| OneHub | ✅（含 Session Cookie） | ✅ | - | - | - |
| Sub2API | - | - | ✅ | ✅ | - |
| Octopus | - | - | ✅（自动登录） | - | ✅ |
| WONG | ✅ | ✅ | - | - | - |

### 额度体系差异

| 后端 | 额度单位 | 无限额度表示 | 过期时间格式 |
|------|---------|------------|------------|
| Common | 内部 quota（×500000） | `unlimited_quota: true` + `remain_quota: -1` | Unix 秒（`-1` = 永不过期） |
| OneHub | 内部 quota（同 Common） | 同 Common | 同 Common |
| Sub2API | USD | `quota: 0` | ISO 8601（创建用 `expires_in_days`） |
| Octopus | USD（`total_cost`） | 不适用 | 不适用 |

### 分组端点差异

| 后端 | 用户分组 | 站点分组 |
|------|---------|---------|
| Common | `GET /api/user/self/groups` | `GET /api/group` |
| OneHub | `GET /api/user_group_map` | 复用 Common |
| Sub2API | `GET /api/v1/groups/available` + `GET /api/v1/groups/rates`（合并） | 不适用 |
| Octopus | `GET /api/v1/group/list` | 不适用 |

---

> 文档生成时间：2026-04-27
> 基于源码版本：`main` 分支 (`57d278b6`)
