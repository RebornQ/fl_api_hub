# B1 — Request Logger Data Layer

## Goal

Provide the in-memory foundation for capturing every Dio request/response: immutable log entries, header-redaction / body-serialization / curl-export pure utilities, an `Interceptor` implementation, and four Riverpod providers (enabled switch, buffer, filter, filtered view). No UI in this batch.

## Deliverables

**Domain entities** (`lib/features/dev_tools/request_logger/domain/entities/`):
- `request_log_entry.dart` — immutable value object with id, timestamps, elapsed, method, url, query, headers (already redacted), body (already serialized/truncated), status, error fields. Provides `isSuccess / isClientError / isServerError / isError` booleans.
- `request_log_filter.dart` — `{keyword, StatusBucket}` filter record.
- `status_bucket.dart` — enum `all / success / clientError / serverError / error` used by the quick filter.

**Data utilities** (`lib/features/dev_tools/request_logger/data/utils/`):
- `header_redactor.dart` — pure `redactHeaders` + `maskSensitiveValue`. Masks `Authorization / Cookie / New-API-User` (case-insensitive) by keeping first+last 4 chars, middle `****`. Values ≤ 8 chars fully masked.
- `body_serializer.dart` — pure `serializeRequestBody` / `serializeResponseBody`. Handles `Map/List` (`jsonEncode`), `String`, `FormData` summary, binary placeholder (Content-Type not JSON/text). Truncates at 64 KB with `...（已截断，原始 X KB）` suffix.
- `curl_exporter.dart` — pure `exportAsCurl(entry)` emitting multi-line curl with redacted headers. Single-quote escaping. FormData body becomes a `# FormData 不支持导出` comment.

**Interceptor** (`lib/features/dev_tools/request_logger/data/interceptors/`):
- `request_logger_interceptor.dart` — stamps an incrementing id + start timestamp on `options.extra` during `onRequest`, emits a `RequestLogEntry` through an injected `onComplete` callback during `onResponse` / `onError`. Must be added **after** `AuthInterceptor` so that the header snapshot reflects the truly outgoing request.

**Riverpod providers** (`lib/features/dev_tools/request_logger/presentation/providers/`):
- `request_logger_providers.dart` containing:
  - `requestLoggerEnabledProvider` (`StateProvider<bool>`, default false, not persisted)
  - `requestLogBufferProvider` (`NotifierProvider`) backed by a `ListQueue<RequestLogEntry>` with 500-entry FIFO
  - `requestLogFilterProvider` (`StateProvider<RequestLogFilter>`)
  - `filteredRequestLogsProvider` (`Provider<List<RequestLogEntry>>`, newest-first)

**Unit tests** (`test/features/dev_tools/request_logger/`):
- `header_redactor_test.dart` — short/long values, case-insensitive matching, non-sensitive headers untouched.
- `body_serializer_test.dart` — JSON, String, FormData summary, binary placeholder, truncation threshold.
- `curl_exporter_test.dart` — redacted header propagation, FormData comment path, single-quote escaping, GET vs POST.
- `request_log_buffer_test.dart` — FIFO at 501 entries, `clear()` resets.
- `request_logger_interceptor_test.dart` — onResponse emits once with elapsed > 0; onError with `DioException.connectionTimeout` emits `statusCode == null` and `errorType == 'connectionTimeout'`.

## Dependencies

None. This is the root batch.

## Verification

- `flutter analyze` clean on new files (note: existing repo may have unrelated warnings).
- `flutter test test/features/dev_tools/` all green.
- All new files use English doc comments matching existing `/// …` style.

## Out of scope

- Dio integration (lives in B2).
- Settings entry / pages / widgets (B2–B4).
- Persistence of any kind.
