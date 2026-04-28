# S2: 敏感信息动态遮蔽 + UI 开关

## Goal

改为 UI 层动态遮蔽敏感 headers，并在详情页 AppBar 添加全局开关。

## Requirements

* 拦截器不再调用 `redactHeaders()`，存储原始 headers 到 `RequestLogEntry`
* `RequestLogEntry.requestHeaders` 语义变更：存储原始值
* 详情页 AppBar 添加"显示敏感信息"切换按钮（默认关闭 = 遮蔽显示）
* `_RequestCard` 根据开关状态动态调用 `redactHeaders()` 遮蔽
* `curl_exporter` 导出时调用 `redactHeaders()` 确保安全
* 更新相关测试

## 改动文件

* `lib/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart`
* `lib/features/dev_tools/request_logger/domain/entities/request_log_entry.dart`
* `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart`
* `lib/features/dev_tools/request_logger/data/utils/curl_exporter.dart`
* `test/features/dev_tools/request_logger/curl_exporter_test.dart`
* `test/features/dev_tools/request_logger/request_logger_interceptor_test.dart`

## Acceptance Criteria

* [ ] AppBar 有切换按钮，默认遮蔽
* [ ] 开启后显示原始敏感 headers 值
* [ ] curl 导出始终使用遮蔽版本
* [ ] Response headers 不受影响（无遮蔽逻辑）
