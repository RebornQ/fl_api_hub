# B3 — Request Logger List Page

## Goal

Introduce the Master-Detail list page and its supporting widgets, wire it into the developer options entry, and finalize the runtime UX for inspecting captured entries. Detail body rendering (group cards + curl export) is still the B4 deliverable; B3 only ships a placeholder detail panel so the master side can be exercised end-to-end (navigate + live-append + filter + clear).

## Deliverables

**New widgets** (`lib/features/dev_tools/request_logger/presentation/widgets/`):
- `request_log_method_badge.dart` — small method pill (GET / POST / PUT / DELETE / PATCH / OTHER), colour-coded.
- `request_log_status_badge.dart` — status code pill (2xx green / 3xx sky / 4xx orange / 5xx red / ERR grey).
- `request_log_list_tile.dart` — single row: method badge + URL (path, ellipsis) + status badge + elapsed (`42 ms`) + trailing chevron. Responsive tap behaviour (highlight vs push) lives in the page.
- `request_log_filter_bar.dart` — `ConsumerWidget` with a `TextField` for URL keyword + horizontally scrollable bucket chips (全部/2xx/4xx/5xx/错误) with counts computed from the live buffer.
- `request_log_detail_placeholder.dart` — a simple centered message "详情内容将在 B4 实现"; used both in the wide-layout detail pane (when nothing selected *or* selected) and as the body of `RequestLogDetailPage`. B4 will replace the internals without renaming the file or public API.

**New providers** (append to `presentation/providers/request_logger_providers.dart`):
- `selectedRequestLogIdProvider` (`StateProvider<int?>`) — selected entry id for the wide-layout detail pane; null = nothing selected.

**New pages** (`lib/features/dev_tools/request_logger/presentation/pages/`):
- `request_logger_page.dart` — `ConsumerStatefulWidget`. `AppBar` with title "请求记录", trailing `Switch.adaptive` (bound to enabled provider), `IconButton(Icons.delete_sweep_outlined)` (confirm dialog → `buffer.clear()` + clears `selectedRequestLogIdProvider`). Body = filter bar + `LayoutBuilder`:
  - ≥900px: `Row` with `SizedBox` (40% width) master + `VerticalDivider` + `Expanded` detail placeholder.
  - < 900px: master list only; tapping a tile → `Navigator.push(RequestLogDetailPage)`.
  Uses `filteredRequestLogsProvider` as source; shows `AppEmptyState` (`icon: Icons.network_check`) when empty (different messages for "switch is off" vs "no matches" vs "nothing captured yet").
- `request_log_detail_page.dart` — small `ConsumerWidget` that takes `int entryId`, looks up the entry in the buffer, and displays `RequestLogDetailPlaceholder` wrapped in a `Scaffold` with an `AppBar('请求详情')`.

**Modify** `developer_options_page.dart`:
- Turn the placeholder "查看请求记录" tile into a live `ListTile` that `Navigator.push`es `RequestLoggerPage`. Keep the trailing chevron and rename subtitle to "实时查看记录/搜索/筛选".

**Widget tests** (`test/features/dev_tools/request_logger/`):
- `request_log_filter_bar_test.dart` — typing in the search field updates `requestLogFilterProvider.keyword`; tapping a bucket chip updates `statusBucket`.
- `request_logger_page_test.dart` — 1) empty state text reflects enabled/disabled; 2) after buffer add, the list tile appears with the URL; 3) tapping the "清空" icon then "确定" clears the buffer; 4) wide-layout builds 2 columns at ≥ 900 px.

## Dependencies

B2 — specifically `developer_options_page.dart` and `requestLoggerEnabledProvider` / `requestLogBufferProvider` / `requestLogFilterProvider` / `filteredRequestLogsProvider`.

## Verification

- `flutter analyze lib/ test/` clean.
- `flutter test test/features/dev_tools/` all green (existing 46 + new widget tests).
- Manual: open the page with switch **off** → empty state text encourages turning the switch on. Flip the in-page `Switch` → state text changes. Manually push an entry via provider from a helper (or hit a real endpoint) → list tile appears. Tap clear → confirm dialog → list empties. Shrink window under 900 px → single column; widen → two columns.

## Out of scope

- The grouped "概览 / Request / Response" Cards inside the detail pane (B4).
- `curl` export button (B4).
- Any kind of sort / grouping beyond newest-first (explicitly out — the plan uses newest-first only).
