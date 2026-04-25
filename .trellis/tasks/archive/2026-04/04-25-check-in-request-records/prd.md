# brainstorm: 签到请求记录查看与持久化

## Goal

用户在签到详情页点击某次签到记录后，可以跳转查看该次签到对应的网络请求详情（请求/响应），便于排查签到失败原因。请求记录需持久化到本地存储，且页面复用现有的 Request Logger 详情组件。

## What I already know

* **签到功能** (`features/check_in/`): `CheckInResultCard` 展示签到结果，`CheckInAccountDetailPage` 展示某账户的签到历史
* **现有请求记录器** (`features/dev_tools/request_logger/`): 完整的请求记录 UI（列表页 + 详情页），当前仅在开发者工具中使用
  - `RequestLogEntry` 实体：包含 method, url, headers, body, statusCode, elapsed 等完整请求信息
  - `RequestLogListTile` / `RequestLogDetailPlaceholder` / `RequestLogDetailPage` 等 UI 组件可复用
  - 当前使用内存 FIFO 缓冲区（500 条），不持久化
  - 通过 `RequestLoggerInterceptor` 拦截所有 Dio 请求
* **路由**: 使用 `IndexedStack` + `Navigator.push`，无 GoRouter
* **持久化**: Hive 存储，box-per-entity 模式，如 `check_in_results` box 限制每账户 50 条
* **CheckInResult 实体**: 包含 id, taskId, accountId, status, message, executedAt 等字段
* **签到执行流程**: `CheckInNotifier.executeAll()` → `CheckInRemoteDataSource.checkIn()` → SiteAdapter

## Assumptions (temporary)

* 需要将 `CheckInResult` 与对应的 `RequestLogEntry` 关联起来（可能通过 requestId 或时间戳匹配）
* 现有 Request Logger 的 UI 组件可以参数化复用（传入特定的请求记录列表）
* 持久化方案使用 Hive（与项目现有模式一致）

## Open Questions

* 如何关联 CheckInResult 与 RequestLogEntry？（需要设计关联机制）
* 请求记录的存储策略：每条签到结果存储多少条关联请求？
* 是否需要修改现有 RequestLoggerInterceptor，还是创建独立的拦截器？

## Requirements (evolving)

* 签到详情列表项点击后跳转到请求记录页面
* 请求记录页面复用现有 Request Logger 的详情组件
* 请求记录持久化到本地（Hive）
* 每次签到执行时捕获对应的网络请求

## Acceptance Criteria (evolving)

* [ ] 点击签到记录可跳转到对应的请求详情页
* [ ] 请求记录在 app 重启后依然存在
* [ ] 复用现有 Request Logger 的 UI 组件展示请求详情
* [ ] 签到失败的记录能清晰展示失败请求的详细信息

## Definition of Done

* Lint / typecheck / CI green
* 签到成功和失败场景都能正确记录和展示
* 数据量合理控制，不影响 app 性能

## Out of Scope (explicit)

* 修改开发者工具中的 Request Logger 页面
* 实现请求记录的导出/分享功能

## Technical Notes

* 关键文件:
  - `lib/features/dev_tools/request_logger/domain/entities/request_log_entry.dart` - 请求记录实体
  - `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart` - 详情展示组件
  - `lib/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart` - 请求拦截器
  - `lib/features/check_in/presentation/pages/check_in_account_detail_page.dart` - 签到账户详情页
  - `lib/features/check_in/domain/entities/check_in_result.dart` - 签到结果实体
  - `lib/features/check_in/data/datasources/check_in_remote_datasource.dart` - 远程数据源
  - `lib/core/storage/hive_store.dart` - Hive 存储实现
