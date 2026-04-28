# feat: 请求记录器 - 敏感信息显示 + 移除截断

## Goal

改进请求记录器的开发者体验：
1. 添加敏感信息显示按钮 — 允许开发者查看未遮蔽的 Authorization/Cookie 等敏感头信息
2. 移除请求体和响应体截断 — 完整保留请求/响应数据

## What I already know

### 现有架构

* **拦截器**: `RequestLoggerInterceptor` 在 `onRequest` 捕获请求，在 `onResponse/onError` 构建条目
* **敏感信息处理**: `header_redactor.dart` 定义 `kSensitiveHeaderNames` = {authorization, cookie, set-cookie, new-api-user}，通过 `maskSensitiveValue()` 遮蔽处理
* **截断逻辑**: `body_serializer.dart` 中 `kMaxBodyBytes = 64KB`，`_truncateUtf8()` 截断超限内容
* **UI**: `RequestLogDetailView` 渲染概览/Request/Response 三个 SectionCard，使用 `_KeyValueTable` 展示 headers

### 关键文件

* `lib/features/dev_tools/request_logger/data/utils/header_redactor.dart`
* `lib/features/dev_tools/request_logger/data/utils/body_serializer.dart`
* `lib/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart`
* `lib/features/dev_tools/request_logger/domain/entities/request_log_entry.dart`
* `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart`

## Decision (ADR-lite)

**Context**: 需要决定敏感信息显示的实现方式和截断移除范围

**Decision**:
1. **敏感信息**: 方案 B — UI 层动态遮蔽。拦截器存储原始 headers，UI 层根据开关状态调用 `redactHeaders()` 动态遮蔽
2. **截断范围**: 同时移除请求体和响应体截断，完全保留原始数据
3. **UI 交互**: 全局开关放在详情页 AppBar，控制当前页面的敏感信息显示
4. **安全限制**: 不限制构建模式，所有模式均可使用

**Consequences**:
- 拦截器不再调用 `redactHeaders()`，存储原始 headers
- `RequestLogEntry.requestHeaders` 语义变化：从"已遮蔽"变为"原始值"
- curl 导出仍应使用遮蔽版本（需在导出时调用 redact）
- 内存占用可能因移除截断而增加

## Requirements

### R1: 敏感信息显示按钮

* 拦截器存储原始 headers（不再在拦截器层面遮蔽）
* 详情页 AppBar 添加"显示敏感信息"切换按钮（默认关闭 = 遮蔽）
* UI 层根据开关状态动态调用 `redactHeaders()` 遮蔽敏感头
- 切换按钮仅影响 Request 卡片的 headers 显示区域
- curl 导出始终使用遮蔽版本（保持安全）

### R2: 移除请求体和响应体截断

* 移除 `serializeRequestBody()` 和 `serializeResponseBody()` 中的截断逻辑
* 保留完整请求体和响应体
* 可保留 `kMaxBodyBytes` 常量但不再使用，或直接移除

## Acceptance Criteria

* [ ] 详情页 AppBar 有"显示敏感信息"切换按钮
* [ ] 默认状态：敏感 headers 显示为遮蔽值（如 `Auth****xxxx`）
* [ ] 开启后：显示原始 Authorization/Cookie 等敏感头值
* [ ] 请求体和响应体不再被截断
* [ ] curl 导出始终使用遮蔽版本
* [ ] 现有测试更新并通过

## Definition of Done

* Tests added/updated
* Lint / typecheck / CI green
* 手动测试：敏感信息切换、大响应体完整展示

## Out of Scope (explicit)

* 持久化敏感信息显示偏好设置
* 对请求体/响应体中的敏感字段进行遮蔽（如 JSON body 中的 password/token）
* Response headers 的敏感信息遮蔽（当前只有 request headers 需要）

## Technical Notes

### 改动文件清单

1. **`request_logger_interceptor.dart`**: 移除 `redactHeaders()` 调用，直接存储原始 headers
2. **`body_serializer.dart`**: 移除 `_truncateUtf8()` 调用和 `kMaxBodyBytes` 常量
3. **`request_log_entry.dart`**: 更新文档注释（requestHeaders 语义变化）
4. **`request_log_detail_placeholder.dart`**: 添加切换按钮，_RequestCard 中动态遮蔽 headers
5. **`curl_exporter.dart`**: 导出时调用 `redactHeaders()` 遮蔽敏感头
6. **相关测试文件**: 更新 header_redactor 测试、body_serializer 测试、curl_exporter 测试

## Subtasks

### S1: 移除截断 (body_serializer + interceptor)

- 移除 `kMaxBodyBytes` 和 `_truncateUtf8()`
- `serializeRequestBody()` / `serializeResponseBody()` 直接返回完整字符串
- 更新相关测试

### S2: 敏感信息动态遮蔽 (interceptor + entity + UI)

- 拦截器不再调用 `redactHeaders()`，存储原始 headers
- 更新 `RequestLogEntry` 注释
- `_RequestCard` 添加敏感信息开关状态参数
- 详情页 AppBar 添加切换按钮（IconButton 或 Switch）
- `curl_exporter` 导出时调用 `redactHeaders()`
- 更新相关测试