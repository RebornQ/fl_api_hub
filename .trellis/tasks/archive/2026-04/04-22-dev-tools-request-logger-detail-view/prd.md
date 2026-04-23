# B4 — Request Logger Detail View

## Goal

Replace the B3 placeholder with a production-ready detail view that renders the captured entry in three grouped sections (概览 / Request / Response) and provides a toolbar action to copy the request as a curl command to the system clipboard.

## Deliverables

**Modify**: `lib/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart`
- Rename the widget to `RequestLogDetailView` (keep the file name for git continuity).
- When `entry == null`, show the existing "选择左侧的请求以查看详情" centered message (wide-layout empty state).
- When `entry != null`, render:
  - A `SingleChildScrollView` wrapping three `SectionCard`s (from `core/widgets/`) with `AppSpacing.md` vertical gaps.
  - **概览 Card** (`icon: Icons.info_outline`):
    - Method + URL (single line, ellipsis if too long, monospace font).
    - Status code + label (e.g. `200 OK`, `404 Not Found`, `ERR Timeout`) with colour-coded text.
    - Elapsed time (`42 ms` or `1.23 s`).
    - Timestamps: `startedAt` and `endedAt` formatted as `HH:mm:ss.SSS`.
  - **Request Card** (`icon: Icons.upload_outlined`):
    - Query parameters table (if non-empty): two-column `Table` with key/value pairs, monospace font.
    - Request headers table: same layout, redacted values already baked in.
    - Request body: monospace `Text` with `maxLines: 10` + "展开" / "收起" toggle when body exceeds 10 lines. If body is `null` or empty, show `<无请求体>` placeholder.
  - **Response Card** (`icon: Icons.download_outlined`):
    - Response headers table (if non-empty).
    - Response body: same collapsible pattern as request body. If `null` or empty, show `<无响应体>` or `<请求失败，无响应>` depending on `entry.isError`.
    - Error section (only when `entry.errorType != null`): display `errorType` and `errorMessage` in a red-tinted container.
  - A floating `FloatingActionButton.extended` at the bottom-right with `icon: Icons.content_copy`, `label: 'Copy as curl'`. On tap:
    - Call `exportAsCurl(entry)` from `curl_exporter.dart`.
    - Copy the result to the system clipboard via `Clipboard.setData(ClipboardData(text: curl))`.
    - Show a `SnackBar` with message "已复制 curl 命令到剪贴板".

**Widget structure**:
- Use `SectionCard` from `core/widgets/section_card.dart` for the three groups.
- Use `Table` widget for key-value pairs (headers / query params) with `TableColumnWidth` set to `IntrinsicColumnWidth` for the key column and `FlexColumnWidth` for the value column so keys stay compact and values wrap.
- Collapsible body: `StatefulWidget` or local `useState` (if using hooks) to track `_isBodyExpanded`. When collapsed, `maxLines: 10`; when expanded, `maxLines: null`.

**New test**: `test/features/dev_tools/request_logger/request_log_detail_view_test.dart`
- Renders "选择左侧" message when `entry == null`.
- Renders three `SectionCard`s when `entry != null`.
- Tapping "Copy as curl" FAB copies to clipboard and shows SnackBar (use `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler` to mock the clipboard channel).
- Collapsible body: tapping "展开" increases visible lines; tapping "收起" collapses back.

## Dependencies

B3 — specifically the `RequestLogDetailPlaceholder` file and the `RequestLoggerPage` / `RequestLogDetailPage` that reference it.

## Verification

- `flutter analyze lib/features/dev_tools/ test/features/dev_tools/` clean.
- `flutter test test/features/dev_tools/` all green (existing 58 + new detail view tests).
- Manual: open the logger page, select an entry (wide layout) or tap a tile (narrow layout) → detail view shows three cards with real data. Tap "Copy as curl" → SnackBar appears, paste into terminal → valid curl command with redacted headers.

## Out of scope

- Syntax highlighting for JSON bodies (plain monospace text is sufficient).
- Persistent "expanded" state across entry switches (each entry starts collapsed).
- Export formats other than curl (e.g. Postman collection, HAR).
