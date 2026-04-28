# feat: 请求记录响应体代码渲染美化

## Goal

将请求记录器的请求体和响应体从纯文本 monospace 渲染升级为支持语法高亮的代码渲染，提升 JSON/HTML/XML 等内容的可读性。

## What I already know

### 现有架构

* **详情页**: `RequestLogDetailView` 使用 `_CollapsibleBody` widget 渲染请求体和响应体
* **`_CollapsibleBody`**: 当前用纯 `SelectableText` + monospace 字体，支持展开/收起
* **响应体格式**: `body_serializer.dart` 序列化后为 `String?`，通常是 JSON、HTML、纯文本
* **content-type**: `RequestLogEntry.responseHeaders` / `requestHeaders` 可获取 Content-Type

### 关键文件

* `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart` — 主要改动
* `lib/features/dev_tools/request_logger/data/utils/body_serializer.dart` — body 序列化
* `lib/features/dev_tools/request_logger/domain/entities/request_log_entry.dart` — 实体定义

## Decision (ADR-lite)

**Context**: 需要选择 Flutter 语法高亮库，要求支持文本选择、轻量依赖

**Decision**: 使用 `re_highlight`（Reqable 团队的 highlight.js Dart 移植）
- 输出 `TextSpan` 可直接用于 `SelectableText.rich()`
- 仅依赖 `flutter` + `path` + `collection`，无 native 依赖
- 196 种语言（JSON/XML/HTML 等全覆盖），73 种主题
- 无需异步初始化，同步使用
- HTML 通过 XML 模式高亮（与 highlight.js 上游一致）

**Consequences**:
- 新增一个第三方依赖（轻量）
- 需要手动处理 content-type → 语言检测逻辑
- 大 body（>50KB）需跳过高亮以避免性能问题

## Requirements

* R1: 新增 `re_highlight` 依赖
* R2: 创建语法高亮工具函数：接收 body 文本 + content-type，返回 `TextSpan`
* R3: 从 response/request headers 的 Content-Type 推断语言类型（JSON/XML/纯文本）
* R4: JSON 响应体自动美化格式化（pretty print）
* R5: 改造 `_CollapsibleBody` 使用高亮渲染（请求体 + 响应体均适用）
* R6: 保留现有的展开/收起功能
* R7: 保留文本选择和复制功能
* R8: 大 body（>50KB）跳过高亮，回退到纯文本

## Acceptance Criteria

* [ ] JSON body 显示语法高亮（key/value/string/number/bool/null 不同颜色）
* [ ] XML/HTML body 显示基本语法高亮
* [ ] 纯文本 body 保持原样显示
* [ ] JSON 自动格式化（2 空格缩进）
* [ ] 请求体和响应体均支持高亮
* [ ] 保留展开/收起功能
* [ ] 保留文本选择和复制功能
* [ ] 大 body (>50KB) 自动跳过高亮
* [ ] 深色/浅色模式下高亮主题自适应
* [ ] `flutter analyze` 通过
* [ ] 现有测试通过 + 新增测试

## Definition of Done

* Tests added/updated
* Lint / typecheck / CI green
* 手动测试：JSON/HTML/纯文本渲染效果 + 深色模式

## Out of Scope (explicit)

* 代码折叠（按 JSON key 折叠）
* 自定义高亮主题配色
* 行号显示
* 非 JSON/XML/HTML 的其他语言高亮

## Technical Approach

### 改动文件清单

1. **`pubspec.yaml`**: 添加 `re_highlight: ^0.0.3`
2. **新建 `lib/features/dev_tools/request_logger/presentation/utils/code_highlighter.dart`**:
   - `detectLanguage(String? contentType, String body)` — 从 Content-Type 推断语言
   - `buildHighlightedSpan(String body, String language, TextStyle baseStyle, bool isDark)` — 返回 TextSpan
   - `prettyPrintJson(String body)` — JSON 美化格式化
3. **`request_log_detail_placeholder.dart`**: 修改 `_CollapsibleBody` 在展开状态下使用 `SelectableText.rich(highlightedSpan)` 替代 `SelectableText(body)`

### 集成方式

```dart
// _CollapsibleBody 展开状态
final language = detectLanguage(contentType, body);
final formattedBody = language == 'json' ? prettyPrintJson(body) : body;
final span = buildHighlightedSpan(formattedBody, language, baseStyle, isDark);
SelectableText.rich(span);
```

## Research References

* [`research/syntax-highlighting.md`](research/syntax-highlighting.md) — 5 个 Flutter 语法高亮包对比，推荐 re_highlight

## Technical Notes

* `re_highlight` 的 HTML 高亮使用 XML 模式（highlight.js 标准做法）
* JSON pretty-printing 在显示层处理，不影响存储层
* content-type 检测 fallback：无法确定时尝试 JSON 解析，失败则纯文本
