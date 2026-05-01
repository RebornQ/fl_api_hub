# 修复签到 API 请求实现

## Goal

对照 `docs/API 文档/check-in.request.md` 规格文档，修复现有签到 API 请求实现中的偏差和缺失，使所有已支持站点类型的签到请求完全符合上游 API 规范。

## What I already know

### 已发现的 Bug / 偏差

| # | 问题 | 严重度 | 涉及文件 |
|---|------|--------|---------|
| **B1** | **CommonApiAdapter.checkIn() 未发送请求 body `{}`** | 高 | `common_api_adapter.dart:74-79` |
| **B2** | **VeloeraApiAdapter 缺少 fetchCheckInStatus() 覆写** | 中 | `veloera_api_adapter.dart` |
| **B3** | **WongApiAdapter 签到/状态检查缺少覆写** | 高 | `wong_api_adapter.dart` |
| **B4** | **WONG 和 AnyRouter 被标记为 `_unsupportedSiteTypes`** | 高 | `check_in_notifier.dart:29-33` |
| **B5** | **AnyRouter 完全没有 Adapter** | 高 | 需新建 `anyrouter_adapter.dart` |
| **B6** | **site_adapter_provider 未注册 AnyRouter** | 高 | `site_adapter_provider.dart:43-44` |

### API 文档关键差异矩阵

| 站点类型 | 签到端点 | Body | 特殊 Header | 状态检查端点 | 响应信封 |
|---------|---------|------|------------|------------|---------|
| New API / One API / One Hub / Done Hub / Octopus | POST `/api/user/checkin` | `{}` | — | GET `/api/user/checkin?month=` | `{success, message, data}` |
| **WONG** | POST `/api/user/checkin` | `{}` | GET 状态需 `Cache-Control: no-store` | GET `/api/user/checkin`（无 month） | `{success, message, data: {checked_in, enabled, ...}}` |
| **Veloera** | POST `/api/user/check_in` | **无 body** | — | GET `/api/user/check_in_status` | `{success, data: {can_check_in}}` |
| **AnyRouter** | POST `/api/user/sign_in` | `{}` | `X-Requested-With: XMLHttpRequest` | 同签到端点（双用途） | `{code, ret, success, message}` |

## Cookie 模式验证结论

- `account.accessToken` 对 Cookie 模式存储 session 值，不为空
- `AuthInterceptor` 根据 `authType` 自动选择 `Cookie: session=` 或 `Authorization: Bearer`
- `check_in_notifier.dart:156` 的 `token == null || token.isEmpty` 检查对两种模式均适用

## Requirements (final)

### R1: 修复 CommonApiAdapter.checkIn() 请求体

- 在 `dioClient.getDio(proxy:).request()` 调用中增加 `data: {}` 参数
- 影响站点：new-api, one-api, one-hub, done-hub, octopus, wong-gongyi（继承）
- Veloera 已独立覆写 `checkIn()` 不发送 body，不受影响

### R2: WongApiAdapter 签到覆写

- R2a: `checkIn()` 不需要单独覆写（B1 修复后继承 CommonApiAdapter 自动携带 `{}`）
- R2b: 覆写 `fetchCheckInStatus()`: GET `/api/user/checkin`（无 month 参数）+ `Cache-Control: no-store` header
- WONG 状态检查响应映射：`data.checked_in` → `CheckInStatusDto.checkedInToday`

### R3: VeloeraApiAdapter 状态检查覆写

- 覆写 `fetchCheckInStatus()`: GET `/api/user/check_in_status`
- 解析 `can_check_in` → 映射为 `CheckInStatusDto(checkedInToday: !(can_check_in ?? true))`

### R4: 新建 AnyRouterAdapter

- 直接实现 `SiteAdapter` 接口（不继承 CommonApiAdapter，差异太大）
- `checkIn()`: POST `/api/user/sign_in` + body `{}` + `X-Requested-With: XMLHttpRequest` header
- Cookie-only 认证（AuthInterceptor 已处理）
- 响应解析：`{code, ret, success, message}` 信封 → `CheckInResultDto`
- `fetchCheckInStatus()`: 复用 `checkIn()` 端点（双用途），根据响应推断状态
- 其他方法（account info, tokens 等）返回 unsupported

### R5: 解锁 WONG 和 AnyRouter 签到

- 从 `_unsupportedSiteTypes` 移除 `SiteType.wongGongyi` 和 `SiteType.anyrouter`
- 保留 `SiteType.sub2api`（确实不支持签到）

### R6: 增强 CheckInApiMapper 消息匹配

- 补充关键词覆盖：`今天已经签到`、`已经签到`（`已签到` 子串匹配已覆盖大部分）
- 支持 WONG `enabled=false` 检测（在 `CheckInDataDto` 中增加 `enabled` 字段）
- 支持 AnyRouter 空 message = 已签到判断

## Acceptance Criteria

- [ ] CommonApiAdapter.checkIn() 请求携带 body `{}`
- [ ] WongApiAdapter.checkIn() 请求携带 body `{}`（通过继承）
- [ ] WongApiAdapter.fetchCheckInStatus() 使用正确的端点和 header
- [ ] VeloeraApiAdapter.fetchCheckInStatus() 使用 `/api/user/check_in_status`
- [ ] AnyRouterAdapter 实现并注册，签到请求正确
- [ ] WONG 和 AnyRouter 从 _unsupportedSiteTypes 移除
- [ ] 签到消息匹配覆盖文档中的所有关键词
- [ ] `flutter analyze` 无 warning/error
- [ ] 现有测试通过

## Definition of Done

- `flutter analyze` clean
- 现有测试通过
- 每个 adapter 的签到请求可通过请求日志验证符合 API 文档

## Out of Scope

- Turnstile 辅助验证流程（浏览器扩展专属）
- External Custom Check-in（浏览器扩展专属）
- UI 层面的修改
- 新增单元测试（后续任务）
- Sub2API 签到支持（无签到 API）

## Implementation Plan (subtasks)

### Subtask 1: 修复现有 Adapter 请求格式 (R1 + R3 + R2a)

**修改文件：**
- `lib/core/network/adapters/common_api_adapter.dart` — checkIn() 增加 `data: {}`
- `lib/core/network/adapters/veloera_api_adapter.dart` — 新增 fetchCheckInStatus() 覆写

### Subtask 2: WongApiAdapter 签到/状态覆写 (R2b)

**修改文件：**
- `lib/core/network/adapters/wong_api_adapter.dart` — 新增 fetchCheckInStatus() 覆写

### Subtask 3: 新建 AnyRouterAdapter (R4 + R6)

**新建文件：**
- `lib/core/network/adapters/anyrouter_adapter.dart`

**修改文件：**
- `lib/core/network/site_adapter_provider.dart` — 注册
- `lib/features/check_in/data/models/check_in_api_mapper.dart` — 增强消息匹配
- `lib/core/network/dto/check_in_data_dto.dart` — 增加 enabled 字段

### Subtask 4: 解锁 WONG/AnyRouter + 验证 (R5)

**修改文件：**
- `lib/features/check_in/presentation/providers/check_in_notifier.dart` — 移除限制

**验证：**
- `flutter analyze`
- `flutter test`

## Technical Notes

### 关键文件

- `lib/core/network/adapters/common_api_adapter.dart` — B1
- `lib/core/network/adapters/wong_api_adapter.dart` — B3
- `lib/core/network/adapters/veloera_api_adapter.dart` — B2
- `lib/core/network/adapters/` — B5 (新建)
- `lib/core/network/site_adapter_provider.dart` — B6
- `lib/features/check_in/presentation/providers/check_in_notifier.dart` — B4
- `lib/features/check_in/data/models/check_in_api_mapper.dart` — R6

### AuthInterceptor 行为

- `AuthType.accessToken` → `Authorization: Bearer {token}`
- `AuthType.cookie` → `Cookie: session={token}`
- `userId > 0` → `New-API-User: {userId}`
- AnyRouter 需要额外 `X-Requested-With: XMLHttpRequest`，在 adapter 的 Options.headers 中注入

### Veloera 特殊性

- POST 签到 **不需要** body
- 状态检查端点是 `/api/user/check_in_status`
- `can_check_in`: true=可签到, false=已签到, undefined=不支持

### WONG 特殊性

- GET 状态检查需要 `Cache-Control: no-store` header
- GET 状态检查无 month 参数
- `enabled=false` 表示站点关闭签到功能

### AnyRouter 特殊性

- 端点 `/api/user/sign_in`，header `X-Requested-With: XMLHttpRequest`
- 仅 Cookie 认证
- 响应 `{code, ret, success, message}`（无 data 字段）
- 双用途端点
