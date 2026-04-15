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
│   │   │   └── common_api_adapter.dart  # Common/new-api implementation
│   │   ├── dto/
│   │   │   ├── api_response.dart    # Generic envelope wrapper
│   │   │   ├── user_info_dto.dart
│   │   │   ├── site_status_dto.dart
│   │   │   ├── check_in_result_dto.dart
│   │   │   ├── check_in_status_dto.dart
│   │   │   ├── token_dto.dart
│   │   │   └── access_token_dto.dart
│   │   ├── api_request.dart         # Per-request config (baseUrl + auth)
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
    │   └── data/
    │       ├── datasources/
    │       │   ├── accounts_local_datasource.dart
    │       │   └── accounts_remote_datasource.dart
    │       ├── models/
    │       │   ├── account_mapper.dart
    │       │   └── account_api_mapper.dart
    │       └── domain/
    │           ├── entities/account.dart
    │           └── repositories/accounts_repository.dart
    ├── keys/ (same structure as accounts)
    └── check_in/ (same structure as accounts)
```

---

## Module Organization

- **`core/network/`** — Dio client, per-request auth injection, site adapter interface, DTOs
  - `adapters/` — Concrete site adapter implementations (CommonApiAdapter)
  - `dto/` — API response models (distinct from domain entities and Hive maps)
  - `api_request.dart` — Immutable per-request config (baseUrl + authToken + authType)
- **`core/error/`** — Sealed `AppException` hierarchy + Dio error mapping
- **`core/result/`** — `Result<T>` discriminated union (Success/Failure)
- **`core/storage/`** — Hive (structured data) + SecureStore (credentials)
- **`core/scheduler/`** — Abstract background task scheduler (not yet implemented)
- **`features/<feature>/data/`** — Local + remote data sources, mappers (DTO↔entity, Map↔entity)
- **`features/<feature>/domain/`** — Entities, repository contracts
- **`features/<feature>/presentation/`** — Pages, widgets, Riverpod providers

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
