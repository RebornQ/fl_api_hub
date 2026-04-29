# 账号级 + 全局网络代理配置

## Goal

为本应用新增「网络代理」能力。账号编辑页支持「账号级别代理」配置，
Settings 页支持「全局代理」配置；运行时按「账号级 → 全局 → 直连」的
优先级解析最终生效的代理，作用于所有 Dio HTTP 请求。

## Non-Goals

- 不引入 SOCKS5（仅 HTTP/HTTPS proxy）。
- 不做系统代理自动检测（不读 OS 全局代理）。
- 不做按 `siteType` 或域名维度的细粒度代理路由。
- Web 平台不支持代理（浏览器自身决定），UI 显式提示并禁用。
- 不引入新的网络 SDK；继续使用现有 `dio` 5.x。

## Requirements

### R1：代理实体与字段模型

- 新增 `ProxyConfig` 值对象（domain 层），字段：
  - `host`：String，非空
  - `port`：int，1..65535
  - `scheme`：`http` | `https`（枚举或字符串常量）
  - `username`：String?
  - `password`：String?
- 新增 `AccountProxyMode` 枚举（账号级三态）：
  - `followGlobal`（默认，跟随全局）
  - `direct`（显式直连，覆盖全局）
  - `custom`（使用账号自己的 ProxyConfig）
- `Account` 实体新增字段：
  - `proxyMode: AccountProxyMode`（默认 `followGlobal`）
  - `proxyConfig: ProxyConfig?`（仅 `custom` 模式下使用）
- 新增「全局代理设置」实体 `GlobalProxySetting`：
  - `enabled: bool`（独立开关；关闭后即使有配置也不生效）
  - `config: ProxyConfig?`

### R2：解析优先级（运行时）

- 优先级（从高到低）：
  1. 若 `account.proxyMode == direct` → **强制直连**
  2. 若 `account.proxyMode == custom` → 使用 `account.proxyConfig`
  3. 若 `account.proxyMode == followGlobal`：
     - 全局 `enabled == true` 且 `config != null` → 使用全局
     - 否则 → 直连
- 新增 `ProxyResolver`，输入 `Account` + 当前全局设置，输出最终
  `ProxyConfig?`（`null` 表示直连）。

### R3：Dio 池改造

- `DioClient` 改造为按代理键缓存 Dio 实例：
  - `getDio({ProxyConfig? proxy})`：相同代理键复用同一 Dio。
  - 缓存键：`scheme://[user@]host:port`（密码不入键，但参与 HttpClient
    `findProxy` 的 BasicAuth header）。
  - 每个实例独立持有 `IOHttpClientAdapter` + `HttpClient.findProxy`。
- 默认实例（无代理）保留现有的 `AuthInterceptor` +
  `RequestLoggerInterceptor`；其他实例同样挂上这两个 interceptor，
  避免代理切换导致日志/鉴权丢失。
- 不破坏现有 `dioClientProvider` 调用方；改为：
  - SiteAdapter 调用 `dioClient.getDio(proxy: request.proxy)`。

### R4：ApiRequest 透传 proxy

- `ApiRequest` 新增 `ProxyConfig? proxy` 字段（不可变）。
- 上游构造 `ApiRequest` 时由仓储层调用 `ProxyResolver` 注入。
- 全部 6 个 SiteAdapter（`CommonApiAdapter`/`OneHubAdapter`/
  `DoneHubAdapter`/`VeloeraApiAdapter`/`Sub2ApiAdapter`/`WongApiAdapter`）
  在发起请求时改用 `dioClient.getDio(proxy: request.proxy)`。

### R5：账号编辑 UI

- 在 `account_edit_form.dart` 现有 4 个 SectionCard 之后新增第 5 个：
  - 标题：「网络代理」（icon 建议 `Icons.lan_outlined`）
  - **默认折叠**（参考已有的展开/折叠交互），打开后显示模式切换 +
    字段。
- 模式切换：`SegmentedButton<AccountProxyMode>` 或 3 个
  `RadioListTile`：跟随全局 / 自定义 / 显式直连。
- `custom` 模式：
  - `scheme` 下拉（http/https）
  - `host` 文本字段（必填）
  - `port` 数字字段（1-65535）
  - `username` / `password`（password 隐藏 + 可见性切换，复用
    `_obscureToken` 模式）
  - 「测试代理」按钮：调用网络层提供的 ping 入口，向 `account.baseUrl`
    发一次 `GET /api/status` 或同等轻请求并展示结果（成功 / 超时 /
    HTTP 状态码 / 异常文案）。
- 字段进入 `_FormSnapshot`，参与 dirty 检测。
- Web 平台：显示一行说明文字「Web 端代理由浏览器决定，配置不会生效」，
  字段不禁用以保持配置可备份，但隐藏「测试代理」按钮。

### R6：全局设置 UI

- `settings_page.dart` 新增列表项「网络代理」（`Icons.lan_outlined`），
  点击进入 `NetworkProxySettingsPage`。
- 该页内容：
  - 「启用全局代理」Switch（绑定 `GlobalProxySetting.enabled`）
  - 与账号编辑相同的 host/port/scheme/auth 字段
  - 「测试代理」按钮（向一个固定可达地址，如
    `https://www.gstatic.com/generate_204` 发请求；成功条件 = 状态码
    204 或 2xx）
- 风格与现有 `appearance_settings.dart` / `browser_settings.dart` 保持
  一致。

### R7：持久化

- `Account` 序列化（`AccountMapper.toMap` / `fromMap`）支持
  `proxyMode` + `proxyConfig`；旧记录默认 `followGlobal` + null。
- 新增 settings hive box `network_proxy`（或复用现有 settings box，
  Key：`global_proxy`）。
- 数据源 + 仓储 + Riverpod provider 三件套对齐 `theme` /
  `browser_preference` 现有结构。

### R8：备份 / 恢复

- 备份 / 恢复流程必须包含：
  - 账号的 `proxyMode` + `proxyConfig`
  - 全局 `GlobalProxySetting`
- 备份文件版本号若已有 schema version，需要 bump 并兼容旧版本读取。

### R9：可观察性

- 请求日志 / 检查 (`request_logger`) 若已展示账号 + URL，应额外展示
  「proxy: scheme://host:port」标签（无代理时不显示）。
- 错误处理：代理连接失败时，错误信息中标注 proxy 字符串，便于排查。

## Acceptance Criteria

- [ ] 账号级 `direct` / `custom` / `followGlobal` 三态行为符合 R2 优先级
- [ ] 同一账号连续两次请求复用同一 Dio 实例（无内存泄漏）
- [ ] 切换不同代理配置后，对应 Dio 实例独立工作（互不串扰）
- [ ] 账号编辑表单：代理 SectionCard 默认折叠，dirty 检测正常，
      取消编辑 PopScope 提示生效
- [ ] 全局代理：禁用开关后，`followGlobal` 账号自动直连
- [ ] 测试代理按钮：成功 / 超时 / 认证失败均能正确反馈
- [ ] 备份导出 → 全部清除 → 恢复后，账号代理 + 全局代理均还原
- [ ] Web 平台 UI 显示提示文字，不崩溃
- [ ] `flutter analyze` 0 警告，`dart format .` 已应用
- [ ] 现有签到 / 余额 / token 列表等流程在「跟随全局 + 全局禁用」下
      行为与改造前一致（回归零回退）

## Definition of Done

- 4 个 subtask 全部完成并通过各自 check
- 主任务 lint / typecheck / 现有测试全绿
- 手工回归：
  - 添加新账号 → 自定义代理 → 测试 → 保存 → 触发余额刷新成功
  - 切换为「显式直连」→ 触发刷新 → 成功
  - 全局开启代理 + 账号「跟随全局」→ 触发刷新 → 走代理
  - 全局关闭 + 「跟随全局」→ 直连
  - 备份 → 全清 → 恢复 → 全部配置回位

## Subtasks (build order)

1. **S1 数据层** — `04-30-s1-data-layer`
   - ProxyConfig + AccountProxyMode + GlobalProxySetting + Hive 序列化
   - Account 字段扩展 + Mapper 兼容旧记录
   - 备份序列化补丁
2. **S2 网络层** — `04-30-s2-network-layer`
   - DioClient → Dio 池
   - ProxyResolver
   - ApiRequest.proxy 透传 + 6 个 SiteAdapter 调整
   - 测试连通性 use case（接受 `ProxyConfig` + 目标 URL）
3. **S3 账号编辑 UI** — `04-30-s3-account-edit-ui`
   - account_edit_form 新增 ProxyConfigSection（折叠卡片）
   - 三态切换 + 字段 + 测试按钮
   - dirty / 表单提交集成
4. **S4 全局设置 UI** — `04-30-s4-global-settings-ui`
   - settings_page 新增 tile
   - NetworkProxySettingsPage（启用开关 + 字段 + 测试）
   - 持久化 + Riverpod provider

## Out of Scope

- SOCKS5 / PAC / OS 系统代理读取
- 按域名 / 按 SiteType 的代理规则
- 代理失败自动 fallback 到直连（保持显式语义，错误就报错）
- 代理 latency 性能采集 / 仪表盘

## Technical Notes

- 关键文件：
  - `lib/core/network/dio_client.dart`
  - `lib/core/network/auth_interceptor.dart`
  - `lib/core/network/api_request.dart`
  - `lib/core/network/site_adapter_provider.dart`
  - `lib/features/accounts/domain/entities/account.dart`
  - `lib/features/accounts/data/models/account_mapper.dart`
  - `lib/features/accounts/presentation/widgets/account_edit_form.dart`
  - `lib/features/settings/...`（新增 proxy 三件套）
  - `lib/features/backup/...`（备份/恢复 schema）
- 平台代理 API：`HttpClient.findProxy` + `IOHttpClientAdapter`
- BasicAuth：代理认证用
  `HttpClientBasicCredentials` + `addProxyCredentials`，或在
  `findProxy` 返回串「PROXY user:pass@host:port」（注意 dart:io 不
  支持后者，必须用 addProxyCredentials）。
