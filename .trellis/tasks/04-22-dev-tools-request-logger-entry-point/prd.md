# B2 — Request Logger Entry Point

## Goal

Wire up B1's data layer so the logger switch is actually connected to the live Dio instance, and expose the switch through a new "开发者选项" secondary page reached from the settings tab. After this batch, toggling the switch must add/remove `RequestLoggerInterceptor` on the shared `Dio.interceptors` list in real time; existing call sites (`site_adapter_provider.dart`) keep working unchanged.

## Deliverables

**Modify**: `lib/core/network/dio_client.dart`
- Add `removeInterceptorsOfType<T>()` alongside `addInterceptor()` for symmetrical dynamic control.
- Rework `dioClientProvider` so that:
  - On creation, if `requestLoggerEnabledProvider` is already `true`, attach a `RequestLoggerInterceptor` whose `onComplete` pushes to `requestLogBufferProvider.notifier`.
  - `ref.listen(requestLoggerEnabledProvider, ...)` attaches or removes the logger interceptor on the same instance when the switch flips.
  - Ordering: `AuthInterceptor` remains first (added by `DioClient` constructor), the logger is appended **after** it so header redaction captures the truly outgoing headers.

**New**: `lib/features/dev_tools/request_logger/presentation/pages/developer_options_page.dart`
- `ConsumerWidget` with `Scaffold` + `AppBar('开发者选项')`.
- `SwitchListTile.adaptive` bound to `requestLoggerEnabledProvider` with title "请求记录器", subtitle "打开后记录 App 内每个请求（仅内存，关闭或重启后丢失）".
- Placeholder disabled `ListTile` "查看请求记录（B3 实现）" with a small info hint — replaced in B3.
- Bottom note: "关闭开关不会清空已记录的请求；需手动点击列表页的清空按钮。"

**Modify**: `lib/features/settings/presentation/pages/settings_page.dart`
- Replace the "敬请期待" placeholder with a `ListView` containing (for now) a single tile "开发者选项" → `Navigator.push` to `DeveloperOptionsPage`.
- Scaffold without AppBar — the `AppShell` bottom navigation already frames the page (check other tab pages for the pattern).

## Dependencies

B1 (entities, providers, interceptor) must be merged first.

## Verification

- `flutter analyze lib/core/network/ lib/features/dev_tools/ lib/features/settings/` clean.
- `flutter test test/core/network/` all green (sanity-check site_adapter_provider still compiles).
- Manual: opening the app → Settings tab → "开发者选项" → toggle the switch → with the switch **on**, the number of interceptors on `ref.read(dioClientProvider).dio.interceptors` equals 2 (Auth + Logger); with the switch **off**, equals 1 (Auth only).

## Out of scope

- List page / filter / detail page (B3 + B4).
- Persistence of switch state.
- Visible request log list (placeholder tile is disabled until B3).
