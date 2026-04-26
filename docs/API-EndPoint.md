# API 综合参考

> 本文整合 `API-Compress.md`、`API-EndPoint.md` 与 `API.md`，用于统一说明仓库当前实现中**实际使用**的 HTTP 接口、`siteType` 分发、认证方式、关键调用链，以及不同实现之间的差异。
>
> 它不是某个后端项目的官方 API 文档。若本文与当前代码实现不一致，应以仓库代码为准。

## 文档定位

本页合并了三类信息：

- **速查清单**：快速查看当前实际调用了哪些 endpoint
- **维护者视角**：了解 `apiService` 体系如何分发、拼接 URL、选择认证方式
- **差异矩阵**：查看各 `siteType` 相对 `common` 的 override 行为

主要覆盖范围：

- 按“服务分发器 / 通用请求执行器 / 站点特化适配器”抽象后的 API 端点
- `baseUrl`、认证方式与请求执行路径
- `common` 共享实现与各 `siteType` override 的差异
- 账号刷新、渠道管理、模型同步等关键调用链伪代码
- 自动签到、托管会话、外部集成与上游模型接口

## 站点实现分发

| siteType | 实现模块 | 说明 |
| --- | --- | --- |
| `new-api` | `common` | 默认共享实现 |
| `one-hub` | `oneHub` | 覆盖模型 / 分组 / token 列表读取 |
| `done-hub` | `doneHub` + `oneHub` | 先走 DoneHub 特化，再回退 OneHub / Common |
| `Veloera` | `veloera` | 渠道与签到接口有差异 |
| `wong-gongyi` | `wong` | 主要覆盖签到逻辑 |
| `anyrouter` | `anyrouter` | 签到由 provider 实现，不是标准 REST 接口 |
| `sub2api` | `sub2api` | 独立 `/api/v1/*` 协议与 JWT 流程 |
| `octopus` | `octopus` | 独立 JWT 登录与 `/api/v1/*` 协议 |

## 请求模型与执行链

### 统一请求对象

`common` 体系中统一使用：

```ts
interface ApiServiceRequest {
  auth: AuthConfig
  baseUrl: string
  data?: Record<string, any>
  accountId?: string
}
```

其中 `AuthConfig` 常见字段包括：

- `authType`
- `cookie`
- `accessToken`
- `userId`
- `refreshToken`
- `tokenExpiresAt`

### 通用请求执行链

`common` 体系的主链路大致如下：

1. 业务函数传入 `ApiServiceRequest + endpoint`
2. `_fetchApi()` 使用 `joinUrl(baseUrl, endpoint)` 拼出完整 URL
3. `createRequestHeaders()` 根据认证方式组装 headers
4. `createAuthRequest()` 生成最终 `RequestInit`
5. `fetchApi()` / `fetchApiData()` 发起请求并解析响应
6. 必要时通过 `executeWithTempWindowFallback()` 走临时窗口 fallback

补充说明：

- `/api/log*` 请求会做最小间隔限流，避免高频分页触发上游限流
- 默认情况下，请求 URL 形式为 `baseUrl + endpoint`
- Octopus 不走这条主链，而是使用独立的 `fetchOctopusApi()`

## baseUrl 与认证方式

### baseUrl 常见来源

| 来源 | 迁移用伪代码 | 说明 |
| --- | --- | --- |
| 账号上下文 | `apiContext = buildAccountRequest(accountViewModel)` | 从账号展示层对象提取 `baseUrl + accountId + auth`，构造统一请求对象 |
| Managed site 管理配置 | `adminConfig = readManagedSiteAdminConfig(userPreferences, targetSiteType)` | 从用户偏好读取 `baseUrl + adminToken + userId`，生成管理端请求上下文 |
| 模型同步上下文 | `syncService = new ModelSyncService(baseUrl, adminToken, userId, siteType)` | 模型同步服务初始化时直接绑定目标站点地址与管理凭证 |

### 认证方式

#### Common / New API compatible

| authType | 典型行为 | 说明 |
| --- | --- | --- |
| `Cookie` | `credentials: include`，可附加 `Cookie` header | 常用于自动识别、登录态探测、补建 access token |
| `AccessToken` | `Authorization: Bearer <token>` | 常用于账号管理、渠道管理、token 管理 |
| `None` | 无认证 | 常用于公共接口，如 `/api/status` |

#### Sub2API

- 认证接口位于 `/api/v1/*`
- 使用 dashboard JWT
- 扩展侧会维护 `refreshToken` 与 `tokenExpiresAt`
- 内部会自动执行 hydrate、主动 refresh、401 后 reactive refresh、以及本地登录态 resync

#### Octopus

- 使用 `username + password` 登录 `/api/v1/user/login`
- JWT 仅缓存在内存中，由 `octopusAuthManager` 自动续期
- 部分兼容函数会直接读取 `preferences.octopus`，忽略传入的 `request.auth`

## Common / New API compatible 端点

适用范围：

- `new-api`
- 默认 fallback 实现
- `one-hub` / `done-hub` / `Veloera` / `wong-gongyi` / `anyrouter` 未覆盖部分也会回退到这里

### 账户与站点状态

| 方法 | 端点 | 主要函数 | 说明 |
| --- | --- | --- | --- |
| `GET` | `/api/user/self` | `fetchUserInfo` / `fetchAccountQuota` | 当前用户、quota、账号探测 |
| `GET` | `/api/user/token` | `createAccessToken` | Cookie 登录态下自动创建 access token |
| `GET` | `/api/status` | `fetchSiteStatus` | 公开状态接口 |
| `GET` | `/api/user/payment` | `fetchPaymentInfo` | 支付信息 |
| `GET` | `/api/user/checkin?month=YYYY-MM` | `fetchCheckInStatus` | 月签到状态 |
| `POST` | `/api/user/checkin` | 自动签到 provider | 执行签到 |
| `GET` | `/api/user/models` | `fetchAccountAvailableModels` | 当前账号可用模型 |
| `GET` | `/api/user/self/groups` | `fetchUserGroups` | 当前用户分组 |
| `GET` | `/api/group` | `fetchSiteUserGroups` | 站点全部分组 |
| `GET` | `/api/pricing` | `fetchModelPricing` | 模型定价与分组倍率 |
| `POST` | `/api/user/topup` | `redeemCode` | 兑换码充值 |

补充说明：

- `getOrCreateAccessToken()` 会先调 `fetchUserInfo()`，若响应里没有 token，再调 `createAccessToken()`
- `fetchSupportCheckIn()` 默认不直接调用签到接口，而是读取 `/api/status.checkin_enabled`
- `/api/pricing` 返回不完全等同于标准 `{ success, message, data }` envelope，当前实现按 `PricingResponse` 直接解析

### 日志与今日统计

| 方法 | 端点 | 主要函数 | 说明 |
| --- | --- | --- | --- |
| `GET` | `/api/log/self?...` | `fetchTodayUsage` / `fetchTodayIncome` / `fetchPaginatedLogs` | 默认参数为 `p,page_size,type,token_name,model_name,start_timestamp,end_timestamp,group` |
| `GET` | `/api/log/self/stat?...` | `fetchTodayUsageFast` | 今日消费统计快路径 |

补充说明：

- `fetchTodayUsage()` 会优先尝试：
  - `/api/log/self/stat`
  - `/api/log/self?page_size=1`
- 快路径失败后才回退到完整日志分页聚合
- `fetchTodayIncome()` 仍主要依赖 `/api/log/self` 分页聚合

### 渠道管理

| 方法 | 端点 | 主要函数 | 说明 |
| --- | --- | --- | --- |
| `GET` | `/api/channel/search?keyword=...` | `searchChannel` | 搜索渠道 |
| `POST` | `/api/channel/` | `createChannel` | 创建渠道 |
| `PUT` | `/api/channel/` | `updateChannel` | 更新渠道 |
| `DELETE` | `/api/channel/{id}` | `deleteChannel` | 删除渠道 |
| `GET` | `/api/channel/?p={page}&page_size={size}` | `listAllChannels` | 分页列出渠道 |
| `GET` | `/api/channel/fetch_models/{channelId}` | `fetchChannelModels` | 拉取上游模型 |
| `PUT` | `/api/channel/` | `updateChannelModels` | 更新渠道 models |
| `PUT` | `/api/channel/` | `updateChannelModelMapping` | 更新渠道 models + model_mapping |

补充说明：

- `createChannel()` 会使用包装体 payload：`{ mode, channel }`
- `channel.groups` 会被转换成 `channel.group`

### Token / Key 管理

| 方法 | 端点 | 主要函数 | 说明 |
| --- | --- | --- | --- |
| `GET` | `/api/token/?p={page}&size={size}` | `fetchAccountTokens` | token 列表 |
| `POST` | `/api/token/` | `createApiToken` | 创建 token |
| `GET` | `/api/token/{id}` | `fetchTokenById` | token 详情 |
| `PUT` | `/api/token/` | `updateApiToken` | 更新 token |
| `DELETE` | `/api/token/{id}` | `deleteApiToken` | 删除 token |
| `POST` | `/api/token/{id}/key` | `fetchTokenSecretKeyById` | 获取完整 token key |

补充说明：

- 当列表接口只返回掩码 key 时，`resolveApiTokenKey()` 会自动调用 `/api/token/{id}/key` 补齐真实密钥
- 这是 token 管理流程里一个容易遗漏的隐藏端点

## siteType 特化矩阵

这部分只记录相对 `common` 的差异。

### OneHub

> 另包含 Common 清单。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/available_model` | 模型价格原始数据 |
| `GET` | `/api/user_group_map` | 用户分组映射 |
| `GET` | `/api/token/?p={page}&size={size}` | token 列表，返回结构与 common 略有不同 |

补充说明：

- `fetchModelPricing()` 会并行读取 `available_model + user_group_map`，再转换成统一 `PricingResponse`
- `fetchAccountAvailableModels()` 通过 `Object.keys(availableModel)` 得到模型集合

### DoneHub

> 另包含 OneHub + Common 清单。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/channel/?base_url={keyword}&page=1&size={size}` | 搜索渠道，不走 `/api/channel/search` |
| `POST` | `/api/channel/` | 创建渠道 |
| `PUT` | `/api/channel/` | 更新渠道 |
| `DELETE` | `/api/channel/{id}` | 删除渠道 |
| `GET` | `/api/channel/?page={page}&size={size}` | 分页列渠道 |
| `GET` | `/api/channel/{id}` | 单渠道详情 |
| `POST` | `/api/channel/provider_models_list` | 拉取 provider models |
| `GET` | `/api/group/?page={page}&size={size}` | 分组列表 |
| `GET` | `/api/log/self?...` | 参数改为 `page,size,log_type` |

DoneHub 日志分页兼容规则：

| 项目 | Common | DoneHub |
| --- | --- | --- |
| 页码参数 | `p` | `page` |
| 每页大小 | `page_size` | `size` |
| 日志类型参数 | `type` | `log_type` |
| 列表字段 | `items` | `data` |
| 总数字段 | `total` | `total_count` |
| `group` 参数 | 包含 | 不包含 |

补充说明：

- 更新 channels 的 `models` / `model_mapping` 前，需要先拉完整渠道详情，避免覆盖其它字段
- `/api/log/self/stat`、`/api/available_model`、`/api/user_group_map` 等接口仍可能沿用继承链实现

### Veloera

> 另包含 Common 清单。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `POST` | `/api/channel` | 创建渠道，无尾斜杠 |
| `PUT` | `/api/channel` | 更新渠道，无尾斜杠 |
| `GET` | `/api/channel/?p={page}&page_size={size}` | 分页列渠道，`p=0` 起始 |
| `GET` | `/api/channel/search?keyword=...` | 搜索渠道 |
| `GET` | `/api/channel/{id}` | 单渠道详情 |
| `GET` | `/api/user/check_in_status` | 签到状态 |
| `POST` | `/api/user/check_in` | 自动签到 |

补充说明：

- 渠道列表与搜索结果会先归一化为 `ManagedSiteChannel`
- `fetchCheckInStatus()` 读取的是 `can_check_in`，不是 common 的月签到结构

### WONG 公益站

> 另包含 Common 清单。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/user/checkin` | 签到状态，响应语义与 common 不同 |
| `POST` | `/api/user/checkin` | 自动签到 |

补充说明：

- `fetchSupportCheckIn()` 基于 `fetchCheckInStatus()`，不再依赖 `/api/status.checkin_enabled`
- `/api/user/checkin` 的 `message` 里可能直接体现“今天已签到”
- `fetchCheckInStatus()` 会把“今天还能否签到”转换成 `boolean | undefined`

### AnyRouter

> 另包含 Common 清单。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `POST` | `/api/user/sign_in` | 签到能力由 provider 实现 |

补充说明：

- `fetchSupportCheckIn()` 固定返回 `true`
- `fetchCheckInStatus()` / 实际签到逻辑都委托给 `anyrouterProvider.checkIn(...)`
- 差异点主要在 provider，不在标准 `apiService` REST 封装

### Sub2API

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/v1/auth/me` | 当前用户 |
| `POST` | `/api/v1/auth/refresh` | 刷新 JWT |
| `GET` | `/api/v1/groups/available` | 可用分组 |
| `GET` | `/api/v1/groups/rates` | 分组倍率 |
| `GET` | `/api/v1/keys?page={page}&page_size={size}` | token 列表 |
| `GET` | `/api/v1/keys/{id}` | token 详情 |
| `POST` | `/api/v1/keys` | 创建 token |
| `PUT` | `/api/v1/keys/{id}` | 更新 token |
| `DELETE` | `/api/v1/keys/{id}` | 删除 token |

补充说明：

- 使用 `{ code, message, data }` envelope，而不是 common 的 `{ success, message, data }`
- `executeAuthenticatedSub2ApiRequest()` 会自动处理 JWT hydrate、主动 refresh、401 后 reactive refresh、以及 refresh 失败后的 resync
- 当前实现中：
  - `fetchSupportCheckIn()` 固定返回 `false`
  - `fetchCheckInStatus()` 固定返回 `undefined`
  - `fetchTodayUsage()` / `fetchTodayIncome()` 返回 `0`
  - `fetchAccountAvailableModels()` 返回空数组

### Octopus

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `POST` | `/api/v1/user/login` | 登录获取 JWT |
| `GET` | `/api/v1/channel/list` | 渠道列表 |
| `POST` | `/api/v1/channel/create` | 创建渠道 |
| `POST` | `/api/v1/channel/update` | 更新渠道 |
| `DELETE` | `/api/v1/channel/delete/{id}` | 删除渠道 |
| `POST` | `/api/v1/channel/fetch-model` | 拉取远端模型 |
| `GET` | `/api/v1/model/list` | 模型列表 |
| `GET` | `/api/v1/group/list` | 分组列表 |

补充说明：

- Octopus 使用独立请求器，例如：`octopusResponse = octopusRequest(config, endpoint, options)`，不会复用 common 体系的通用请求执行器
- URL 拼接可抽象为：`url = normalizeBaseUrl(config.baseUrl) + endpoint`
- 兼容函数 `fetchSiteUserGroups()` / `fetchAccountAvailableModels()` 的迁移思路是：当调用端未显式传入完整认证上下文时，可回退读取持久化配置中的 `baseUrl + username + password`

## New API 托管会话 / 敏感操作

这部分不属于普通账号刷新接口，而是托管站点能力所需的 Cookie 会话辅助流程。

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/user/2fa/status` | 读取 2FA 状态 |
| `GET` | `/api/user/passkey` | 读取 Passkey 状态 |
| `POST` | `/api/user/login` | 发起登录 |
| `POST` | `/api/user/login/2fa` | 提交登录 2FA |
| `POST` | `/api/verify` | 提交安全验证 |
| `POST` | `/api/channel/{channelId}/key` | 读取隐藏渠道 key |

## 自动签到端点汇总

| 站点 | 方法 | 端点 |
| --- | --- | --- |
| New API / Common 兼容族 | `POST` | `/api/user/checkin` |
| WONG 公益站 | `POST` | `/api/user/checkin` |
| Veloera | `POST` | `/api/user/check_in` |
| AnyRouter | `POST` | `/api/user/sign_in` |

## 站点识别 / 探测相关请求

| 功能 | 方法 | 端点 | 说明 |
| --- | --- | --- | --- |
| 获取站点原始标题 | `GET` | `/` | 读取 HTML `<title>` |
| 探测用户接口特征 | `GET` | `/api/user/self` | Cookie 模式下读取错误特征辅助识别站点 |

## 集成接口

### Claude Code Router

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/api/config` | 获取配置 |
| `POST` | `/api/config` | 保存配置 |
| `POST` | `/api/restart` | 重启服务 |

### LDOH

| 方法 | 完整地址 | 说明 |
| --- | --- | --- |
| `GET` | `https://ldoh.105117.xyz/api/sites` | 获取站点目录 |

补充说明：

- `https://ldoh.105117.xyz/?q={hostname}` 是页面 URL，不是 API 端点

## 上游模型接口

这些接口用于验证或读取上游供应商模型列表，不属于站点后台管理接口。

### OpenAI Compatible

| 方法 | 端点 |
| --- | --- |
| `GET` | `/v1/models` |

### Anthropic

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/v1/models?limit=200&after_id=...` | 分页拉取，带 `x-api-key` 和 `anthropic-version` |

### Google / Gemini

| 方法 | 端点 | 说明 |
| --- | --- | --- |
| `GET` | `/v1beta/models` | 首页 |
| `GET` | `/v1beta/models?pageToken=...` | 下一页 |

## CLI 支持验证模板

这组是“验证目标端点模板”，不是扩展核心业务流固定调用的站点后台接口。

| 工具 | 方法 | 端点模板 |
| --- | --- | --- |
| Claude | `POST` | `/v1/messages` |
| Codex | `POST` | `/v1/responses` |
| Gemini | `POST` | `/v1beta/models/{model}:generateContent` |

## 关键调用链

### 1. 账号探测 / 刷新

迁移视角主入口：`detectAndRefreshAccount(inputUrl, authMode)`

典型流程：

1. 自动识别站点类型与用户身份
2. 调用 `service = getApiService(siteType)` 选择具体实现
3. 使用 `fetchUserInfo()` / `getOrCreateAccessToken()` / `fetchAccountData()`
4. 最终落到：
   - `common` family：`read account snapshot -> choose site adapter -> call shared request executor`
   - 特化 family：`override selected capabilities -> fallback to inherited shared behavior`

### 2. Managed site 渠道管理

迁移视角主入口：`manageChannels(targetSiteType, adminPreferences)`

典型流程：

1. 从用户偏好中读取 managed-site admin 配置
2. 构造 `ApiServiceRequest`
3. 调用 `searchChannel()` / `createChannel()` / `updateChannel()` / `deleteChannel()`
4. 由 `getApiService(siteType)` 自动路由到 common 或 override 实现

### 3. 模型同步

迁移视角主入口：`syncChannelModels(baseUrl, adminToken, userId, siteType)`

典型流程：

1. `listAllChannels()` 拉取远端渠道列表
2. `fetchChannelModels()` 获取渠道上游模型
3. 经过过滤 / 比较后
4. 使用 `updateChannelModels()` 或 `updateChannelModelMapping()` 回写

> 因为这些方法都走 `getApiService(this.siteType)`，所以同步逻辑本身不需要知道底层是 New API、DoneHub 还是 Octopus，只依赖统一签名。

## 关键代码伪代码

- `service = getApiService(siteType)`
- `request = { baseUrl, accountId?, auth }`
- `headers = buildRequestHeaders(auth)`
- `requestInit = createAuthenticatedRequest(headers, options)`
- `response = executeRequestWithFallback(baseUrl, endpoint, requestInit)`
- `data = unwrapApiEnvelopeIfNeeded(response)`
- `resolvedTokenKey = resolveSecretKeyWhenInventoryOnlyReturnsMaskedValue(token)`
- `sessionState = ensureManagedSession(baseUrl, credentials, verificationState)`
- `models = syncService.fetchChannelModels(channelId)`
- `service.updateChannelModelMapping(channelId, models, modelMapping)`

## 维护建议

### 1. 新增或修改端点时优先检查这些抽象职责

- 站点分发器：根据 `siteType` 选择 shared 或 override 实现
- 通用请求执行器：负责 URL 拼接、认证头、错误处理与 fallback
- 共享业务适配层：封装账户、渠道、token、日志、定价等标准接口
- 站点 override 适配层：仅覆盖与 shared 协议不兼容的差异点

### 2. 新增 `siteType` override 时，至少同步更新两处

- `站点实现分发`
- `siteType 特化矩阵`

### 3. 文档更新原则

- 以当前仓库代码实现为准
- 优先维护这一份综合文档，避免多份文档漂移
- 对迁移文档优先描述“职责 + 调用顺序 + 数据形状”，弱化框架与仓库路径耦合
- 若后续需要拆分对外文档，可再按用途拆为：
  1. 站点后台接口
  2. 外部供应商接口
  3. 查询接口与写操作接口
  4. Common / Sub2API / Octopus 三大体系
