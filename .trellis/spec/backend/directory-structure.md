# Directory Structure

> How backend code is organized in this project.

---

## Overview

This repository does not currently contain implemented backend source code. It is a Flutter application bootstrap repository, and the only app code today is frontend code in `lib/main.dart` plus tests in `test/widget_test.dart`.

However, the target architecture documented in `CLAUDE.md` plans application-side data, domain, and integration layers under `lib/`. This guide documents the current reality and the intended placement for future app-side backend-like concerns such as networking, storage, repositories, and domain logic.

---

## Directory Layout

Current implemented state:

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   ├── shell/app_shell.dart
│   └── theme/
│       ├── app_theme.dart
│       └── design_tokens.dart
├── core/
│   ├── error/
│   │   ├── app_exception.dart       # Sealed exception hierarchy
│   │   └── failure_mapper.dart      # Dio → AppException mapper
│   ├── network/
│   │   ├── adapters/
│   │   │   ├── common_api_adapter.dart  # Common/new-api implementation
│   │   │   └── veloera_api_adapter.dart # Extends common, overrides check-in path
│   │   ├── dto/
│   │   │   ├── api_response.dart    # Generic envelope wrapper
│   │   │   ├── user_info_dto.dart
│   │   │   ├── site_status_dto.dart
│   │   │   ├── check_in_result_dto.dart  # Top-level check-in response (success + message + data)
│   │   │   ├── check_in_data_dto.dart    # Nested check-in data (checkin_date + quota_awarded)
│   │   │   ├── check_in_status_dto.dart
│   │   │   ├── token_dto.dart
│   │   │   └── access_token_dto.dart
│   │   ├── api_request.dart         # Per-request config (baseUrl + auth + userId)
│   │   ├── auth_interceptor.dart    # Per-request auth injection
│   │   ├── dio_client.dart          # Shared Dio instance
│   │   ├── site_adapter.dart        # Abstract adapter interface
│   │   ├── site_adapter_provider.dart # Riverpod adapter registry
│   │   └── site_type.dart           # SiteType + AuthType enums
│   ├── result/
│   │   └── result.dart              # Result<T> = Success | Failure
│   ├── scheduler/
│   │   └── scheduler.dart           # Abstract scheduler interface
│   ├── storage/
│   │   ├── hive_store.dart          # Hive KeyValueStore
│   │   └── secure_store.dart        # FlutterSecureStorage wrapper
│   └── widgets/
│       ├── app_scaffold.dart
│       ├── app_loading_state.dart
│       ├── app_error_state.dart
│       └── app_empty_state.dart
└── features/
    ├── accounts/
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   ├── accounts_local_datasource.dart
    │   │   │   └── accounts_remote_datasource.dart
    │   │   ├── models/
    │   │   │   ├── account_mapper.dart
    │   │   │   └── account_api_mapper.dart
    │   │   └── repositories/
    │   │       └── accounts_repository_impl.dart  # Local CRUD via Hive + SecureStore
    │   ├── domain/
    │   │   ├── entities/account.dart
    │   │   └── repositories/accounts_repository.dart  # Abstract interface
    │   └── presentation/
    │       ├── pages/accounts_page.dart
    │       └── providers/
    │           ├── accounts_providers.dart  # Repository + Notifier provider declarations
    │           └── accounts_notifier.dart   # AsyncNotifier (CRUD + toggleEnabled)
    ├── keys/ (same structure, plus FamilyAsyncNotifier for per-account scoping)
    └── check_in/ (same structure, plus executeCheckIn orchestration + FutureProvider.family for results + domain/services/ for cross-entity reconciliation)
```

---

## Module Organization

- **`core/network/`** — Dio client, per-request auth injection, site adapter interface, DTOs
  - `adapters/` — Concrete site adapter implementations
    - `common_api_adapter.dart` exposes the shared HTTP / envelope plumbing via a single
      `@protected performRequest<T>({method, path, request, fromJson, queryParameters, data})`
      hook. Site-specific subclasses (e.g. `VeloeraApiAdapter`) extend `CommonApiAdapter` and
      override only the endpoints that differ (e.g. Veloera's `/api/user/check_in` snake-case
      path). This avoids duplicating Dio setup and auth/extra forwarding.
    - **Exception: Check-in endpoints** — `checkIn()` methods in both `CommonApiAdapter` and
      `VeloeraApiAdapter` do NOT use `performRequest`. They parse `CheckInResultDto` directly
      from the response and always return `Success` when HTTP 200, regardless of the
      `apiResponse.success` field. This is because New-API returns `success: false` for
      "already checked in" scenarios, which is a valid business state, not an error.
      Status determination is delegated to `CheckInApiMapper`.
    - Subclasses must update `site_adapter_provider.dart` to replace the `SiteType → adapter`
      map entry, otherwise fallback silently routes the site through `CommonApiAdapter`.
  - `dto/` — API response models (distinct from domain entities and Hive maps)
    - `check_in_result_dto.dart` — Top-level response with `success`, `message`, and `data` fields
    - `check_in_data_dto.dart` — Nested data object with `checkin_date` and `quota_awarded`
  - `api_request.dart` — Immutable per-request config (baseUrl + authToken + authType + userId)
- **`core/error/`** — Sealed `AppException` hierarchy + Dio error mapping
- **`core/result/`** — `Result<T>` discriminated union (Success/Failure)
- **`core/storage/`** — Hive (structured data) + SecureStore (credentials)
- **`core/scheduler/`** — Abstract background task scheduler (not yet implemented)
- **`features/<feature>/data/`** — Local + remote data sources, mappers (DTO↔entity, Map↔entity)
  - `repositories/` — Concrete repository implementations (wrap local datasources, return `Result<T>`)
- **`features/<feature>/domain/`** — Entities, repository contracts (abstract interfaces)
  - `services/` — Stateless domain services that coordinate multiple entities (e.g.
    `AccountCheckInSyncService` reconciles `Account.checkIn.autoCheckInEnabled` into the
    `CheckInTask` store via an idempotent upsert — no delete, no history loss).
- **`features/<feature>/presentation/`** — Pages, widgets, Riverpod providers
  - `providers/` — Provider declarations (`*_providers.dart`) + AsyncNotifier classes (`*_notifier.dart`)

---

## Special Case: Check-in Response Handling

### Problem

New-API's check-in endpoint returns `success: false` for "already checked in today" scenarios:

```json
{"message":"今日已签到","success":false}
```

This is a valid business state, not an error. However, the standard `performRequest` method treats `success: false` as a failure and returns `Failure<T>`, causing the UI to incorrectly display "failed" for already-checked-in cases.

### Solution

The `checkIn()` methods in both `CommonApiAdapter` and `VeloeraApiAdapter` bypass `performRequest` and implement custom response handling:

1. **Parse directly**: Call `CheckInResultDto.fromJson()` directly on `response.data`
2. **Always succeed on HTTP 200**: Return `Success<CheckInResultDto>` for any HTTP 200 response
3. **Delegate status determination**: Let `CheckInApiMapper.inferStatus()` determine the actual status based on DTO content

### Status Mapping

`CheckInApiMapper.inferStatus()` maps DTO to `CheckInStatus`:

| Condition | Status | UI Display | Stats Count |
|-----------|--------|------------|-------------|
| `success: true` | `success` | Green "成功" | Success |
| `success: false` + "已签到" | `alreadyChecked` | Purple "已签到" | Success |
| `success: false` + other | `failed` | Red "失败" | Failed |
| Account disabled / no userId | `skipped` | Purple "已跳过" | Skipped |

### Implementation Details

**CommonApiAdapter.checkIn:**
```dart
@override
Future<Result<CheckInResultDto>> checkIn(ApiRequest request) async {
  try {
    final response = await dioClient.dio.request('/api/user/checkin', ...);
    final dto = CheckInResultDto.fromJson(response.data);
    return Success<CheckInResultDto>(dto);
  } on DioException catch (e, st) {
    return Failure<CheckInResultDto>(mapToAppException(e, st));
  }
}
```

**VeloeraApiAdapter.checkIn:**
- Same logic, different path: `/api/user/check_in` (snake_case)

### Testing

See `test/core/network/adapters/common_api_adapter_test.dart`:
- HTTP 200 + `success: true` → `Success`
- HTTP 200 + `success: false` + "已签到" → `Success`
- HTTP 200 + `success: false` + other error → `Success`
- `DioException` → `Failure`

---

## Naming Conventions

- Use `snake_case.dart` for files.
- Name feature folders by feature intent, not by technical layer alone.
- Keep cross-feature abstractions in `core/`, not copied into each feature.
- Do not invent `services/`, `api/`, or `repositories/` top-level roots outside the target structure unless the architecture decision changes first.

---

## Examples

- `CLAUDE.md` — source of truth for the planned app-side architecture.
- `lib/core/network/` — API adapter pattern with per-request auth.
- `lib/core/result/result.dart` — functional error handling via Result<T>.
