# S1: 移除请求/响应体截断

## Goal

移除 `body_serializer.dart` 中的截断逻辑，完整保留请求体和响应体数据。

## Requirements

* 移除 `kMaxBodyBytes` 常量和 `_truncateUtf8()` 函数
* `serializeRequestBody()` 和 `serializeResponseBody()` 直接返回完整字符串
* 更新相关单元测试（移除截断相关断言）

## 改动文件

* `lib/features/dev_tools/request_logger/data/utils/body_serializer.dart`
* `test/features/dev_tools/request_logger/body_serializer_test.dart`

## Acceptance Criteria

* [ ] 大于 64KB 的请求/响应体完整保留
* [ ] 无截断后缀提示
* [ ] 现有测试通过（更新后）
