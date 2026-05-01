# 签到 API 请求规格文档

> **生成日期**: 2026-05-02  
> **数据来源**: all-api-hub 代码库中各后端 provider 的请求构造逻辑及上游 API 类型定义  
> **适用版本**: 本文档记录各后端 API 的通用规格；具体部署版本可能存在字段差异，已标注版本来源

---

## 目录

1. [通用说明](#1-通用说明)
2. [New API 签到](#2-new-api-签到-apiusercheckin)
3. [WONG 公益站签到](#3-wong-公益站签到-apiusercheckin)
4. [Veloera 签到](#4-veloera-签到-apiusercheck_in)
5. [AnyRouter 签到](#5-anyrouter-签到-apiusersign_in)
6. [External Custom Check-in](#6-external-custom-check-in)
7. [通用状态检查端点](#7-通用状态检查端点)
8. [辅助状态端点](#8-辅助状态端点)
9. [签到前置条件](#9-签到前置条件)
10. [消息关键词匹配规则](#10-消息关键词匹配规则)
11. [完整错误码矩阵](#11-完整错误码矩阵)

---

## 1. 通用说明

### 1.1 通用响应信封

所有后端 API 共用以下响应格式（New API / WONG / Veloera / One API / DoneHub 均适用）：

```ts
// ApiResponse<T> — 通用响应信封
interface ApiResponse<T> {
  success: boolean   // 操作是否成功
  data: T            // 业务数据载荷，类型取决于具体端点（失败时可能省略或为 null）
  message: string    // 提示消息（可为空字符串）
}
```

AnyRouter 使用略有不同的信封：

```ts
// AnyRouter 响应信封
interface AnyRouterResponse {
  code: number       // HTTP 状态类代码
  ret: number        // 内部返回码
  success: boolean   // 操作是否成功
  message: string    // 提示消息
}
```

### 1.2 底层 fetchApi 请求构造

所有签到请求均通过 `fetchApi` / `fetchApiData` 工具函数发起，该函数根据 `authType` 自动构造请求：

```
┌─────────────────────────────────────────────────────┐
│                fetchApi 请求构造流程                  │
├─────────────────────────────────────────────────────┤
│  输入: { baseUrl, auth: { authType, accessToken,    │
│          userId, cookie }, endpoint, options }       │
│                                                      │
│  ┌──────────────────────┐                            │
│  │ 1. URL 拼接          │                            │
│  │    baseUrl + endpoint │                           │
│  └────────┬─────────────┘                            │
│           ▼                                          │
│  ┌──────────────────────┐                            │
│  │ 2. 请求头构造         │                           │
│  │    Content-Type:      │                           │
│  │      application/json │                           │
│  │    Pragma: no-cache   │                           │
│  └────────┬─────────────┘                            │
│           ▼                                          │
│  ┌──────────────────────────────────────┐            │
│  │ 3. 认证头注入 (按 authType 分支)      │            │
│  │                                      │            │
│  │ authType = AccessToken:              │            │
│  │   → Authorization: Bearer {token}    │            │
│  │   → credentials: "omit"             │            │
│  │                                      │            │
│  │ authType = Cookie:                   │            │
│  │   → credentials: "include"          │            │
│  │   → 可选 User-ID 兼容头注入          │            │
│  │                                      │            │
│  │ authType = None:                     │            │
│  │   → 无认证头                         │            │
│  └──────────────────────────────────────┘            │
│           ▼                                          │
│  ┌──────────────────────┐                            │
│  │ 4. 发起 fetch 请求    │                            │
│  └──────────────────────┘                            │
└─────────────────────────────────────────────────────┘
```

#### 请求头详情

| 认证方式 | 请求头 | 值 | credentials |
|---------|--------|----|-------------|
| Access Token | `Authorization` | `Bearer {access_token}` | `omit` |
| Access Token | `Content-Type` | `application/json` | — |
| Access Token | `Pragma` | `no-cache` | — |
| Cookie | `Content-Type` | `application/json` | `include` |
| Cookie | `Pragma` | `no-cache` | — |
| Cookie (兼容) | `User-ID` | `{user_id}` 字符串 | — |
| None | `Content-Type` | `application/json` | `omit` |

> **注意**: Cookie 认证模式下浏览器自动携带该域下的所有 Cookie。兼容 `User-ID` 头用于某些需要用户标识但不需要签名的部署变体。

---

## 2. New API 签到 (`/api/user/checkin`)

> **来源版本**: New API (原版 + 主流 fork)，基于 One API 下游衍生  
> **Provider 实现**: 提供完整的自动签到 + Turnstile 辅助 + Incognito 回退链  

### 2.1 签到状态检查

查询当前月份的签到记录和今日状态。

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user/checkin?month={YYYY-MM}` |
| **Auth** | Access Token (`Authorization: Bearer`) 或 Cookie |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| `month` | `string` | Query | **required** | 查询月份，格式 `YYYY-MM`（如 `2026-05`）。取前 7 个字符用于匹配 |

#### 响应参数

```ts
// CheckInStatus — 签到状态响应载荷
interface CheckInStatusResponse {
  data: CheckInStatus
  success: boolean
}

interface CheckInStatus {
  enabled: boolean                    // 站点是否启用签到功能
  max_quota: number                   // 签到单次奖励最大额度
  min_quota: number                   // 签到单次奖励最小额度
  stats: {
    checked_in_today: boolean         // 今天是否已签到
    checkin_count: number             // 当月签到次数
    records: CheckinRecord[]          // 当月签到记录列表
    total_checkins: number            // 历史总签到次数
    total_quota: number               // 历史签到累计额度
  }
}

interface CheckinRecord {
  checkin_date: string                // 签到日期，格式 YYYY-MM-DD（如 "2026-05-02"）
  quota_awarded: number               // 该次签到获得的额度
}
```

#### 响应字段标记

| 字段路径 | 类型 | 必返 | 描述 |
|---------|------|------|------|
| `data` | `CheckInStatus` | **required** | 签到状态数据 |
| `data.enabled` | `boolean` | **required** | 是否启用签到 |
| `data.max_quota` | `number` | **required** | 最高奖励额度 |
| `data.min_quota` | `number` | **required** | 最低奖励额度 |
| `data.stats` | `object` | **required** | 统计信息 |
| `data.stats.checked_in_today` | `boolean` | **required** | 今日是否签到 |
| `data.stats.checkin_count` | `number` | **required** | 当月次数 |
| `data.stats.records` | `CheckinRecord[]` | **required** | 签到记录 |
| `data.stats.total_checkins` | `number` | **required** | 历史总次数 |
| `data.stats.total_quota` | `number` | **required** | 历史总额度 |

#### 示例

**curl**:
```bash
curl -X GET "https://your-new-api.site/api/user/checkin?month=2026-05" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -H "Pragma: no-cache"
```

**TypeScript**:
```ts
const month = new Date().toISOString().slice(0, 7)
const response = await fetch(
  `https://your-new-api.site/api/user/checkin?month=${month}`,
  {
    method: "GET",
    headers: {
      "Authorization": "Bearer sk-xxx",
      "Content-Type": "application/json",
      "Pragma": "no-cache",
    },
  }
)
const { data, success } = await response.json()
console.log(data.stats.checked_in_today) // => true/false
```

### 2.2 签到执行

执行每日签到操作。

| 项目 | 内容 |
|------|------|
| **Method** | `POST` |
| **Endpoint** | `/api/user/checkin` |
| **Auth** | Access Token (`Authorization: Bearer`) 或 Cookie |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| `{}` | `object` | Body (JSON) | **required** | 空 JSON 对象 `{}` |

#### 响应参数

```ts
// NewApiCheckinResponse — 签到执行响应
interface NewApiCheckinResponse {
  data: CheckinRecord                 // 单次签到记录
  success: boolean                    // 签到是否成功
  message: string                     // 提示消息，典型值见下表
}

// CheckinRecord — 签到记录
interface CheckinRecord {
  checkin_date: string                // YYYY-MM-DD 格式日期
  quota_awarded: number               // 本次签到获得的额度
}
```

#### 响应字段标记

| 字段 | 类型 | 必返 | 描述 |
|------|------|------|------|
| `success` | `boolean` | **required** | 签到是否成功 |
| `message` | `string` | **required** | 提示消息 |
| `data` | `CheckinRecord` | **optional** | 签到记录，失败时可能省略 |
| `data.checkin_date` | `string` | **required** (when data exists) | 签到日期 |
| `data.quota_awarded` | `number` | **required** (when data exists) | 获得额度 |

#### 典型 message 值

| message | 含义 | success |
|---------|------|---------|
| `"签到成功"` | 签到成功 | `true` |
| `"今日已签到"` | 今日已签到过 | `false` |
| `"今天已经签到过了"` | 今日已签到过 | `false` |
| `"签到失败：更新额度出错"` | 额度更新失败 | `false` |
| `"Turnstile token 校验失败"` | Turnstile token 无效 | `false` |
| `"Turnstile token 为空"` | Turnstile token 缺失 | `false` |

#### 示例

**curl (Access Token)**:
```bash
curl -X POST "https://your-new-api.site/api/user/checkin" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -H "Pragma: no-cache" \
  -d '{}'
```

**TypeScript (Access Token)**:
```ts
const response = await fetch("https://your-new-api.site/api/user/checkin", {
  method: "POST",
  headers: {
    "Authorization": "Bearer sk-xxx",
    "Content-Type": "application/json",
    "Pragma": "no-cache",
  },
  body: "{}",
})
const { success, data, message } = await response.json()
if (success) {
  console.log(`签到成功，获得 ${data.quota_awarded} 额度`)
} else if (message.includes("已签到")) {
  console.log("今日已签到")
}
```

**curl (Cookie 认证)**:
```bash
curl -X POST "https://your-new-api.site/api/user/checkin" \
  -H "Content-Type: application/json" \
  -H "Pragma: no-cache" \
  -H "User-ID: 1" \
  -b "session=xxx; connect.sid=xxx" \
  -d '{}'
```

---

## 2.3 Turnstile 辅助验证流程 (New API 专属)

当 New API 站点部署了 Cloudflare Turnstile 人机验证后，直接 POST 签到会收到 Turnstile 相关错误。系统实现了以下完整链路来自动通过 Turnstile 验证。

### 触发条件 (消息关键词匹配)

POST 签到响应的 `message` 字段必须同时满足以下条件才触发 Turnstile 辅助流程：

| 条件 | 匹配逻辑 |
|------|---------|
| message 包含 `"turnstile"` (不区分大小写) | `normalized.includes("turnstile")` |
| **且** message 还包含以下任意一个词: | `"token"`, `"verify"`, `"invalid"`, `"failed"`, `"校验"`, `"为空"`, `"失败"` |

### ASCII 时序图

```
  Provider          Background        TempWindow        Turnstile        New API
     │                   │                 │                 │               │
     │  POST /api/user/checkin (空body)   │                 │               │
     │──────────────────────────────────────────────────────────────────────>│
     │                   │                 │                 │    返回 msg   │
     │   success=false, message 包含 "Turnstile token 校验失败"              │
     │<──────────────────────────────────────────────────────────────────────│
     │                   │                 │                 │               │
     │  isTurnstileRequiredMessage() → true                                  │
     │                   │                 │                 │               │
     │  resolveTurnstileAssistedCheckinResult()                              │
     │                   │                 │                 │               │
     │  打开检查页面 (e.g. /console/personal)                                 │
     │─────────────────────────────>│                                         │
     │                   │          │  ┌────页面加载────┐                     │
     │                   │          │  │ 检测 Turnstile  │                    │
     │                   │          │  │ 等待 token 获取  │                    │
     │                   │          │  │ (timeout: 预设值)│                   │
     │                   │          │  └──────┬─────────┘                     │
     │                   │          │         ▼                              │
     │                   │          │  POST /api/user/checkin?turnstile={tk} >│
     │                   │          │         │              返回结果        │
     │                   │          │         │<─────────────────────────────│
     │                   │          │         │                              │
     │                   │          │ ① token_obtained → 成功                │
     │                   │          │ ② token_expired → 超时 fail             │
     │                   │          │ ③ not_present  → ↓                    │
     │                   │          │                                        │
     │                   │          │  ┌─ not_present 分支 ─┐                │
     │                   │          │  │ 没有 Turnstile widget│              │
     │                   │          │  │ 说明已登录的用户     │              │
     │                   │          │  │ 自己签到过了        │              │
     │                   │          │  │                     │              │
     │                   │          │  │ GET /api/user/checkin│             │
     │                   │          │  │ ?month={YYYY-MM}     │             │
     │                   │          │  │─────────────────────────────────────>│
     │                   │          │  │         checked_in_today?            │
     │                   │          │  │<─────────────────────────────────────│
     │                   │          │  │         ↑ true → ALREADY_CHECKED     │
     │                   │          │  │         ↓ false → 尝试 Incognito    │
     │                   │          │  └────────────────────┘                │
     │                   │          │                                        │
     │                   │          │  ┌─ Incognito 分支 ─┐                  │
     │                   │          │  │ 开启隐身窗口     │                  │
     │                   │          │  │ 重新打开检查页面  │                  │
     │                   │          │  │ 检测 Turnstile    │                  │
     │                   │          │  │ 获取 token        │                  │
     │                   │          │  │ POST checkin      │                  │
     │                   │          │  └──────┬───────────┘                  │
     │                   │          │         ▼                              │
     │                   │          │ ② 成功 → STANDARD RESULT               │
     │                   │          │ ③ 失败 → MANUAL_REQUIRED              │
     │<───返回结果────────┴──────────┴────────┘                              │
```

### Turnstile 流程各阶段产出

| 阶段 | Turnstile 状态 | 行为 |
|------|---------------|------|
| 初始判断 | — | `isTurnstileRequiredMessage(message)` 返回 `true` |
| 临时窗口获取 | `token_obtained` | 带 token 的 re-fetch 成功，进入 `resolveStandardCheckinResult` |
| 临时窗口获取 | `token_expired` | 超时未获取 token，检查 `checked_in_today` |
| 临时窗口获取 | `not_present` | 无 Turnstile widget，说明当前登录用户已签到 |
| not_present 确认 | `checked_in_today=true` | → `ALREADY_CHECKED` |
| not_present 确认 | `checked_in_today=false` | → 进入 Incognito retry |
| Incognito retry | 成功 | → 标准结果判断 |
| Incognito retry | 失败 | → `FAILED` (手动验证提示) |
| Incognito 不可用 | — | → `FAILED` (提示需要在浏览器设置中开启无痕模式) |

### Turnstile Pre-trigger 配置

对于仅在用户点击"签到"按钮后才渲染 Turnstile 的站点，可通过 `turnstilePreTrigger` 配置：

```ts
type TurnstilePreTrigger =
  | { kind: "checkinButton" }          // 默认：在检查页面自动点击签到按钮
  | { kind: "custom"; selector: string } // 自定义：指定 CSS 选择器
```

### Turnstile 辅助请求详情

临时窗口中构造的 re-fetch 请求：

```ts
// Turnstile 辅助 POST 参数
const turnstileAssistedRequest: RequestInit = {
  method: "POST",
  body: "{}",
  headers: {
    "Content-Type": "application/json",
    "Pragma": "no-cache",
    "User-ID": "{account_info.id}",     // 当使用 Access Token 时注入
    "Authorization": "Bearer {token}",  // 当 authType = AccessToken 时
  },
  credentials: authType === Cookie ? "include" : "omit",
}
```

---

## 3. WONG 公益站签到 (`/api/user/checkin`)

> **来源版本**: WONG 公益站 (独立部署)  
> **Provider 实现**: 直接 POST 签到 + GET 状态检查，无 Turnstile 辅助  

### 3.1 签到状态检查

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user/checkin` |
| **Auth** | Access Token 或 Cookie (自动将 None 降级为 AccessToken) |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| _(无)_ | — | — | — | 无查询参数 |

#### 特殊请求头

| 请求头 | 值 | 说明 |
|--------|----|------|
| `Cache-Control` | `no-store` | 强制不使用缓存，确保获取最新状态 |

#### 响应参数

```ts
// WongCheckinApiResponse — WONG 签到响应信封
interface WongCheckinApiResponse {
  success: boolean                    // 签到操作是否成功
  message: string                     // 提示消息
  data?: WongCheckinStatusData        // 签到状态数据（未签到时必然返回）
}

// WongCheckinStatusData — WONG 签到状态载荷
interface WongCheckinStatusData {
  checked_at: number                  // 上次签到时间戳（Unix 秒）
  checked_in: boolean                 // 今日是否已签到
  enabled: boolean                    // 站点是否启用签到
  max_quota: number                   // 单次签到最高额度
  min_quota: number                   // 单次签到最低额度
  quota: number                       // 本次签到获得的额度
}
```

#### 响应字段标记

| 字段 | 类型 | 必返 | 描述 |
|------|------|------|------|
| `success` | `boolean` | **required** | 操作是否成功 |
| `message` | `string` | **required** | 提示消息 |
| `data` | `WongCheckinStatusData` | **optional** | 签到数据，失败/无权限时省略 |
| `data.enabled` | `boolean` | **required** | 签到是否启用（`false` 时视为不支持签到） |
| `data.checked_in` | `boolean` | **required** | 今日是否已签到 |
| `data.checked_at` | `number` | **required** | Unix 时间戳(秒) |
| `data.quota` | `number` | **required** | 本次获得的额度 |
| `data.max_quota` | `number` | **required** | 额度上限 |
| `data.min_quota` | `number` | **required** | 额度下限 |

#### 示例

**curl**:
```bash
curl -X GET "https://your-wong-site.site/api/user/checkin" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -H "Cache-Control: no-store"
```

**TypeScript**:
```ts
const response = await fetch("https://your-wong-site.site/api/user/checkin", {
  method: "GET",
  headers: {
    "Authorization": "Bearer sk-xxx",
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
  },
})
const { success, data, message } = await response.json()
// data.enabled === false → 签到功能已关闭
// data.checked_in === true → 今日已签到
// success === true && data.checked_in → 查询成功，已签到
```

### 3.2 签到执行

| 项目 | 内容 |
|------|------|
| **Method** | `POST` |
| **Endpoint** | `/api/user/checkin` |
| **Auth** | Access Token 或 Cookie |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| `{}` | `object` | Body (JSON) | **required** | 空 JSON 对象 |

#### 响应参数

同 [3.1 响应参数](#响应参数-1)，但语义不同：

| 场景 | success | data | message |
|------|---------|------|---------|
| 签到成功 | `true` | `{ enabled, checked_in: true, quota, ... }` | `""` |
| 今日已签到 | `false` | `undefined` | `"今天已经签到过啦"` |
| 签到已禁用 | — | `{ enabled: false }` | — |
| 其他失败 | `false` | `undefined` | 错误消息 |

#### 示例

**curl**:
```bash
curl -X POST "https://your-wong-site.site/api/user/checkin" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**TypeScript**:
```ts
const response = await fetch("https://your-wong-site.site/api/user/checkin", {
  method: "POST",
  headers: {
    "Authorization": "Bearer sk-xxx",
    "Content-Type": "application/json",
  },
  body: "{}",
})
const { success, data, message } = await response.json()

if (data?.enabled === false) {
  console.log("签到功能已被站点关闭")
} else if (success) {
  console.log(`签到成功，获得 ${data.quota} 额度`)
} else if (data?.checked_in === true) {
  console.log("今日已签到")
} else if (message.includes("已经签到")) {
  console.log("今日已签到")
}
```

---

## 4. Veloera 签到 (`/api/user/check_in`)

> **来源版本**: Veloera (New API 下游 fork)  
> **差异说明**: 端点路径使用 `check_in`（下划线风格）而非 `checkin`，独立的状态检查端点 `check_in_status`，POST 签到无 request body  

### 4.1 签到状态检查

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user/check_in_status` |
| **Auth** | Access Token 或 Cookie |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| _(无)_ | — | — | — | 无参数 |

#### 响应参数

```ts
// Veloera check-in status response (包裹在 ApiResponse 中)
interface VeloeraCheckInStatusData {
  can_check_in?: boolean              // 今天是否可以签到（true=未签到，false=已签到）
}
```

#### 响应字段标记

| 字段 | 类型 | 必返 | 描述 |
|------|------|------|------|
| `data` | `object` | **required** | 状态数据 |
| `data.can_check_in` | `boolean` | **optional** | 仅当明确为 `true`/`false` 时有效；`undefined` 表示不支持签到 |

#### 状态判断逻辑

```
can_check_in === true   → 今天可以签到 (未签到)
can_check_in === false  → 今天已签到
can_check_in === undefined → 端点不支持签到或站点无签到功能
404 / 500 错误          → 不支持签到
```

#### 示例

**curl**:
```bash
curl -X GET "https://your-veloera.site/api/user/check_in_status" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json"
```

**TypeScript**:
```ts
const response = await fetch(
  "https://your-veloera.site/api/user/check_in_status",
  {
    method: "GET",
    headers: {
      "Authorization": "Bearer sk-xxx",
      "Content-Type": "application/json",
    },
  }
)
const { data } = await response.json()
if (data?.can_check_in === true) {
  console.log("可以签到")
} else if (data?.can_check_in === false) {
  console.log("今天已签到")
}
```

### 4.2 签到执行

| 项目 | 内容 |
|------|------|
| **Method** | `POST` |
| **Endpoint** | `/api/user/check_in` |
| **Auth** | Access Token 或 Cookie |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| _(无)_ | — | Body | **optional** | Veloera POST 签到不发送 body，仅指定 `method: "POST"` |

> **注意**: Veloera POST 签到与其他后端不同，请求中**不需要**发送 `"{}"`；直接 POST 到端点即可。

#### 响应参数

```ts
// ApiResponse<unknown> — Veloera 签到响应
interface VeloeraCheckinResponse {
  success: boolean                    // 签到是否成功
  message: string                     // 提示消息
  data?: unknown                      // 签到数据（格式可能随版本变化）
}
```

#### 响应字段标记

| 字段 | 类型 | 必返 | 描述 |
|------|------|------|------|
| `success` | `boolean` | **required** | 操作成功标志 |
| `message` | `string` | **required** | 提示消息 |
| `data` | `unknown` | **optional** | 额外数据，失败时可能省略 |

#### 典型 message 值

| message | success | 含义 |
|---------|---------|------|
| `"签到成功"` | `true` | 签到成功 |
| `"今日已签到"` / `"今天已经签到过了"` | — | 已签到 |
| 其他 | `false` | 签到失败 |

#### 示例

**curl**:
```bash
curl -X POST "https://your-veloera.site/api/user/check_in" \
  -H "Authorization: Bearer sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
  -H "Content-Type: application/json"
```

**TypeScript**:
```ts
const response = await fetch("https://your-veloera.site/api/user/check_in", {
  method: "POST",
  headers: {
    "Authorization": "Bearer sk-xxx",
    "Content-Type": "application/json",
  },
})
const { success, message, data } = await response.json()
if (success) {
  console.log("签到成功")
} else if (message.includes("已签到")) {
  console.log("今日已签到")
}
```

---

## 5. AnyRouter 签到 (`/api/user/sign_in`)

> **来源版本**: AnyRouter (独立后端家族)  
> **特殊说明**: 此为**双用途端点**——无独立状态检查 API，通过 POST 签到执行后的响应状态判断是否已签到  

### 5.1 端点规格 (签到 + 状态检查)

| 项目 | 内容 |
|------|------|
| **Method** | `POST` |
| **Endpoint** | `/api/user/sign_in` |
| **Auth** | **强制 Cookie**，不支持 Access Token |
| **双用途** | 既是签到执行端，也是事实上的状态检查端 |

#### 请求参数

| 参数 | 类型 | 位置 | 必填 | 描述 |
|------|------|------|------|------|
| `{}` | `object` | Body (JSON) | **required** | 空 JSON 对象 |

#### 特殊请求头

| 请求头 | 值 | 说明 |
|--------|----|------|
| `X-Requested-With` | `XMLHttpRequest` | **必需**，标识 AJAX 请求 |

#### 响应参数

```ts
// AnyRouter 签到响应
interface AnyRouterCheckinResponse {
  code: number                        // 响应代码
  ret: number                         // 内部返回码
  success: boolean                    // 签到是否成功
  message: string                     // 提示消息（可为空字符串）
}
```

#### 响应字段标记

| 字段 | 类型 | 必返 | 描述 |
|------|------|------|------|
| `code` | `number` | **required** | 响应代码 |
| `ret` | `number` | **required** | 内部返回码 |
| `success` | `boolean` | **required** | 成功标志 |
| `message` | `string` | **required** | 消息（可能为空字符串） |

#### 双用途判断逻辑

```
                        POST /api/user/sign_in
                                │
                                ▼
                    ┌─────────────────────┐
                    │ response.success?    │
                    └──────┬──────────────┘
                           │
              ┌────────────┼──────────────┐
              ▼            ▼              ▼
          true           false          error
              │            │              │
              ▼            │              ▼
    ┌─────────────────┐    │    ┌──────────────────┐
    │ message 包含:     │    │    │ message 为"" →    │
    │ "success" 或     │    │    │ ALREADY_CHECKED  │
    │ "签到成功"        │    │    │                  │
    │                  │    │    │ message 含关键词:  │
    │ → SUCCESS        │    │    │ → ALREADY_CHECKED │
    └──────────────────┘    │    └──────────────────┘
                            │
                            ▼
                  ┌─────────────────────┐
                  │ FAILED              │
                  │ (message 不为空时   │
                  │  保留原始消息；      │
                  │  为空时使用 fallback) │
                  └─────────────────────┘
```

AnyRouter 有一个独特的特征：**成功签到但 message 为空字符串时，也视为已签到**。

#### 示例

**curl**:
```bash
curl -X POST "https://your-anyrouter.site/api/user/sign_in" \
  -H "Content-Type: application/json" \
  -H "X-Requested-With: XMLHttpRequest" \
  -b "session=xxx; connect.sid=xxx" \
  -d '{}'
```

**TypeScript**:
```ts
const response = await fetch("https://your-anyrouter.site/api/user/sign_in", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Requested-With": "XMLHttpRequest",
  },
  credentials: "include",
  body: "{}",
})
const { code, ret, success, message } = await response.json()

const isAlreadyChecked =
  message.trim() === "" ||
  message.toLowerCase().includes("already") ||
  message.includes("已经签到") ||
  message.includes("已签到")

if (success && (message.includes("success") || message.includes("签到成功"))) {
  console.log("签到成功")
} else if (isAlreadyChecked) {
  console.log("今日已签到")
} else {
  console.log("签到失败:", message)
}
```

### 5.2 签到前置条件 (AnyRouter 专属)

AnyRouter 的 `canCheckIn` 判断条件：

| 条件 | 说明 |
|------|------|
| `checkIn.enableDetection === true` | 必须开启签到检测 |
| `account_info.id` 存在 | 必须有用户 ID |
| 无 access_token 要求 | Cookie 模式不需要额外的 token，永远返回 `true` |

---

## 6. External Custom Check-in

> **来源版本**: 扩展自定义功能  
> **场景**: 针对魔改站点或自定义签到 URL 的场景，通过打开外部页面完成签到  

### 6.1 Runtime Message 协议

External Custom Check-in 不同于其他后端，**不发送 HTTP API 请求**，而是通过浏览器扩展的 Runtime Message 机制协调后台打开页面。

#### 请求消息

```ts
// ExternalCheckInOpenAndMark
interface ExternalCheckInRequest {
  action: "externalCheckIn:openAndMark"    // RuntimeActionIds.ExternalCheckInOpenAndMark
  accountIds: string[]                     // 需要签到的账号 ID 列表
  openInNewWindow?: boolean                // 是否在新窗口打开（默认 false=标签页）
}
```

#### 响应消息

```ts
interface ExternalCheckInResponse {
  success: boolean
  data?: {
    results: ExternalCheckInOpenResult[]  // 每个账号的执行结果
    openedCount: number                    // 成功打开签到页面的数量
    markedCount: number                    // 成功标记为已签到的数量
    failedCount: number                    // 失败数量
    totalCount: number                     // 总数
  }
  error?: string
}

interface ExternalCheckInOpenResult {
  accountId: string                        // 账号 ID
  openedCheckIn: boolean                   // 签到页面是否打开成功
  openedRedeem: boolean | null             // 充值页面是否打开成功（null=不打开充值页）
  markedCheckedIn: boolean                 // 是否已标记为已签到
  error?: string                           // 签到页面错误
  redeemError?: string                     // 充值页面错误
}
```

### 6.2 执行流程

```
  UI (popup/options)     Background Service        Browser Tabs
         │                       │                      │
         │ sendRuntimeMessage()  │                      │
         │ { action: ExternalCheckInOpenAndMark,         │
         │   accountIds: [...] } │                      │
         │──────────────────────>│                      │
         │                       │                      │
         │              ┌────────┴────────┐             │
         │              │ 遍历 accountIds │             │
         │              └────────┬────────┘             │
         │                       │                      │
         │              ┌────────▼────────┐             │
         │              │ 读取账号配置    │             │
         │              │ 解析 checkInUrl │             │
         │              │ 解析 redeemUrl  │             │
         │              └────────┬────────┘             │
         │                       │                      │
         │              ┌────────▼────────┐             │
         │              │ openInNewWindow?│             │
         │              └──┬──────────┬───┘             │
         │                 │true      │false            │
         │                 ▼          ▼                 │
         │           createWindow  createTab            │
         │                 │          │                 │
         │                 │   ┌──────┴───────┐         │
         │                 │   │ 打开签到 URL  │────────>│
         │                 │   └──────────────┘         │
         │                 │          │                 │
         │                 │   (可选) 打开 redeem URL   >│
         │                 │          │                 │
         │                 │   ┌──────▼───────┐         │
         │                 │   │ markAccount  │         │
         │                 │   │ AsCustom     │         │
         │                 │   │ CheckedIn()  │         │
         │                 │   └──────────────┘         │
         │                       │                      │
         │  ◄──── 返回结果 ──────│                      │
         │                       │                      │
```

### 6.3 页面打开行为

| 模式 | `openInNewWindow` | API 可用 | 行为 |
|------|-------------------|----------|------|
| 标签页 | `false` (默认) | — | 在当前窗口创建新标签页 |
| 新窗口首次 | `true` | Windows API 可用 | `createWindow({ url })` 创建新窗口，记录 `targetWindowId` |
| 新窗口后续 | `true` | Windows API 可用 | `createTab(url, active, { windowId: targetWindowId })` 在同一窗口中新增标签 |
| 新窗口回退 | `true` | Windows API 不可用 | 回退到 `createTab` 标签页模式 |

### 6.4 标记机制

```
签到页面打开成功 → markAccountAsCustomCheckedIn(accountId)
签到页面打开失败 → 不标记，记录 error
充值页面打开失败 → 不影响签到标记，仅记录 redeemError
```

---

## 7. 通用状态检查端点

以下后端**没有独立的自动签到 Provider**，但支持通过通用端点检查签到状态。

### 7.1 通用签到状态查询

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/user/checkin?month={YYYY-MM}` |
| **Auth** | Access Token 或 Cookie |

响应格式与 [New API 签到状态检查](#21-签到状态检查) 一致，使用 `CheckInStatus` 类型。

#### 适用后端

| 后端 | 状态检查 | 自动签到 Provider | 说明 |
|------|---------|-------------------|------|
| One API | 通用端点 | 无 | 上游原始版本，无 Turnstile |
| One Hub | 通用端点 | 无 | 前端路径不同 (`/panel/`) |
| Done Hub | 通用端点 | 无 | 使用自有 `TodayLogQueryConfig` 覆写日志查询，签到状态检查复用通用代码 |
| Rix API | — | 无 | 自定义前端路径 (`/panel`, `/topup`) |
| Octopus | — | 无 | 无签到相关代码 |

### 7.2 站点签到启用判断

通过 `/api/status` 端点获取站点全局签到开关状态：

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/status` |
| **Auth** | None（公开端点） |

#### 响应关键字段

```ts
interface SiteStatusInfo {
  checkin_enabled?: boolean           // 站点是否启用签到功能（undefined=未知或不支持）
}
```

**curl**:
```bash
curl -X GET "https://site.com/api/status"
```

---

## 8. 辅助状态端点

### 8.1 站点状态概览 (`/api/status`)

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/status` |
| **Auth** | None |

#### 响应参数

```ts
interface SiteStatusInfo {
  price?: number                        // 汇率价格（优先级最高）
  stripe_unit_price?: number            // Stripe 单价（次优先）
  PaymentUSDRate?: number               // 支付美元汇率（OneHub/DoneHub 兼容）
  system_name?: string                  // 系统名称
  checkin_enabled?: boolean             // 是否启用签到功能
}
```

### 8.2 日志统计 (`/api/log/self/stat`)

用于获取签到收入的额度统计（轻量路径）。

| 项目 | 内容 |
|------|------|
| **Method** | `GET` |
| **Endpoint** | `/api/log/self/stat?{params}` |
| **Auth** | Access Token 或 Cookie |

#### 响应参数

```ts
interface LogStatResponseData {
  quota?: number                        // 消耗额度合计
  rpm?: number                          // 每分钟请求数
  tpm?: number                          // 每分钟 token 数
}
```

---

## 9. 签到前置条件

### 9.1 Provider 选择

自动签到调度 (`autoCheckinScheduler`) 根据 `account.site_type` 选择对应的 Provider：

| site_type | Provider | 文件 |
|-----------|----------|------|
| `new-api` | `newApiProvider` | `providers/newApi.ts` |
| `Veloera` | `veloeraProvider` | `providers/veloera.ts` |
| `wong-gongyi` | `wongGongyiProvider` | `providers/wong.ts` |
| `anyrouter` | `anyrouterProvider` | `providers/anyrouter.ts` |
| 其他 | `null` | 无可用的自动签到 Provider |

### 9.2 统一前置条件 (`canCheckIn`)

所有 Provider 在执行签到前必定检查的条件：

| 条件 | New API | WONG | Veloera | AnyRouter |
|------|---------|------|---------|-----------|
| `checkIn.enableDetection === true` | **必须** | **必须** | **必须** | **必须** |
| `account_info.id` 存在 | **必须** | **必须** | **必须** | **必须** |
| AccessToken 模式需有 `access_token` | **必须** | **必须** | **必须** | — |
| Cookie 模式 | 永远通过 | 永远通过 | 永远通过 | 永远通过 |

### 9.3 调度层跳过条件

签到调度器在执行前还会检查以下条件（不满足则跳过，不计为失败）：

| 跳过原因 | Skip Reason | 说明 |
|---------|-------------|------|
| 账号级自动签到开关关闭 | `auto_checkin_disabled` | `account.checkIn.autoCheckin` 为 false |
| 检测关闭 | `detection_disabled` | `account.checkIn.enableDetection` 为 false |
| 无可用 Provider | `no_provider` | `resolveAutoCheckinProvider` 返回 null |
| Provider 不可用 | `provider_not_ready` | `canCheckIn` 返回 false |

---

## 10. 消息关键词匹配规则

### 10.1 已签到判断关键词

所有 Provider 共用 `isAlreadyCheckedMessage()` 进行消息匹配：

| 关键词 | 匹配方式 | 适用范围 |
|--------|---------|---------|
| `今天已经签到` | `includes` (不区分大小写) | 所有 Provider |
| `已经签到` | `includes` (不区分大小写) | 所有 Provider |
| `已签到` | `includes` (不区分大小写) | 所有 Provider |
| `already` | `includes` (不区分大小写) | 所有 Provider |
| 空字符串 `""` | `trim() === ""` | **AnyRouter 专属** |

### 10.2 成功签到判断关键词

| 关键词 | 适用 Provider | 上下文 |
|--------|-------------|--------|
| `success` | AnyRouter | `message.includes("success")` (不区分大小写) |
| `签到成功` | AnyRouter | `message.includes("签到成功")` |

New API / WONG / Veloera 中，成功判断走 `response.success === true` 而非关键词匹配。

### 10.3 Turnstile 判断关键词

| 关键词 | 匹配逻辑 | 适用 Provider |
|--------|---------|-------------|
| `turnstile` | `includes` + 且包含以下之一 | **New API 专属** |
| — `token` | | |
| — `verify` | | |
| — `invalid` | | |
| — `failed` | | |
| — `校验` | | |
| — `为空` | | |
| — `失败` | | |

---

## 11. 完整错误码矩阵

### 11.1 HTTP 层错误

| HTTP 状态码 | Provider 行为 | 结果状态 |
|-------------|-------------|---------|
| `401` | 需重新认证 | `FAILED` (rawMessage: error.message) |
| `404` | 端点不支持签到 | `FAILED` (messageKey: `endpointNotSupported`) |
| `500` | 服务端错误 | 状态检查返回 `undefined`；签到执行返回 `FAILED` |
| 网络错误 (TypeError: fetch) | 网络不可达 | `FAILED` (rawMessage: error.message) |
| 超时 | — | `FAILED` (rawMessage: error.message) |

### 11.2 业务层错误

| 场景 | Provider | 返回状态 | messageKey / rawMessage |
|------|----------|---------|------------------------|
| 签到成功 (success=true) | 所有 | `SUCCESS` | `checkinSuccessful` fallback |
| 今日已签到 (message 含关键词) | New API / WONG / Veloera | `ALREADY_CHECKED` | `alreadyCheckedToday` fallback |
| 今日已签到 (message 为空) | AnyRouter | `ALREADY_CHECKED` | `alreadyCheckedToday` fallback |
| 签到已禁用 (enabled=false) | WONG | `FAILED` | `checkinDisabled` |
| 无可用 Provider | 所有 | `SKIPPED` | `no_provider` |
| Provider 未就绪 | 所有 | `SKIPPED` | `provider_not_ready` |
| 账号未开启检测 | 所有 | `SKIPPED` | `detection_disabled` |
| 自动签到开关关闭 | 所有 | `SKIPPED` | `auto_checkin_disabled` |
| 未知错误 (无 message) | 所有 | `FAILED` | `unknownError` fallback |

### 11.3 Turnstile 错误 (New API 专属)

| 场景 | 触发条件 | 结果状态 | messageKey |
|------|---------|---------|-----------|
| 需手动 Turnstile 验证 | token 未获取且非 not_present | `FAILED` | `turnstileManualRequired` |
| 需开启无痕模式 | not_present + incognito 不可用 | `FAILED` | `turnstileIncognitoAccessRequired` |
| token 获取但签到仍失败 | Turnstile token 获取但 API 返回非成功 | `FAILED` | rawMessage 保留错误信息 |
| not_present 但已签到 | not_present + checked_in_today=true | `ALREADY_CHECKED` | `alreadyCheckedToday` |
| not_present + incognito 成功 | incognito retry 返回标准结果 | 取决于 incognito 响应 | — |
| not_present + incognito 失败 | incognito retry 也失败 | `FAILED` | `turnstileManualRequired` |

### 11.4 External Check-in 错误

| 场景 | openedCheckIn | markedCheckedIn | error |
|------|---------------|-----------------|-------|
| 无效 accountId | `false` | `false` | `"Invalid accountId"` |
| 账号不存在 | `false` | `false` | `"Account not found"` |
| 缺少自定义签到 URL | `false` | `false` | `"Missing custom check-in URL"` |
| 签到页面打开失败 | `false` | `false` | `"Failed to open check-in tab"` |
| 充值页面打开失败 | `true` (签到成功) | `true` (签到成功) | redeemError: `"Failed to open redeem tab"` |
| 标记失败 | `true` | `false` | — |

---

> **文档结束** — 本文档涵盖项目代码库中所有的签到 API 请求路径、参数、响应及错误处理逻辑。如发现文档与实际行为不一致，请以最新代码为准。
