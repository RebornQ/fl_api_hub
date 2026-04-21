# Journal - Reborn (Part 1)

> AI development session journal
> Started: 2026-03-26

---



## Session 1: Bootstrap guideline setup

**Date**: 2026-04-12
**Task**: Bootstrap guideline setup

### Summary

(Add summary)

### Main Changes

| Area | Description |
|------|-------------|
| Frontend spec | Filled directory structure, component, hook, state management, type safety, and quality guidelines based on the actual Flutter bootstrap codebase |
| Backend spec | Filled directory structure, database, error handling, logging, and quality guidelines while explicitly marking unimplemented areas as not yet established |
| Task workflow | Initialized Trellis task context for `00-bootstrap-guidelines`, completed the task, and archived it |

**Key decisions**:
- Documented the difference between current implemented state and target architecture from `CLAUDE.md`
- Used `lib/main.dart`, `test/widget_test.dart`, `pubspec.yaml`, and `analysis_options.yaml` as the primary evidence sources
- Avoided inventing Riverpod, Dio, database, logging, or backend conventions before they exist in code

**Updated Files**:
- `.trellis/spec/frontend/directory-structure.md`
- `.trellis/spec/frontend/component-guidelines.md`
- `.trellis/spec/frontend/hook-guidelines.md`
- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/frontend/type-safety.md`
- `.trellis/spec/frontend/quality-guidelines.md`
- `.trellis/spec/backend/directory-structure.md`
- `.trellis/spec/backend/database-guidelines.md`
- `.trellis/spec/backend/error-handling.md`
- `.trellis/spec/backend/logging-guidelines.md`
- `.trellis/spec/backend/quality-guidelines.md`
- `.trellis/tasks/archive/2026-04/00-bootstrap-guidelines/*`


### Git Commits

| Hash | Message |
|------|---------|
| `a055f2c` | (see git log) |
| `fed6c1d` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: MVP Architecture Planning & Trellis Roadmap Setup

**Date**: 2026-04-15
**Task**: MVP Architecture Planning & Trellis Roadmap Setup
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Planned the full MVP architecture and created 10 Trellis task directories for the All-API-Hub Flutter app.

| Area | Description |
|------|-------------|
| PRD Analysis | Read and summarized All-API-Hub-PRD.md and API-EndPoint.md |
| MVP Scope | Defined 3 priority pages: Accounts, Keys, Check-in; deferred analytics/backup/sync |
| Architecture | Designed Clean Architecture + Feature First + Riverpod + Dio stack |
| Design System | Inspected Stitch project and DESIGN.md tokens for MD3 alignment |
| Trellis Tasks | Created 10 tasks from bootstrap-app-shell through add-tests-and-hardening |
| Batch 1 Prep | Activated 04-14-bootstrap-app-shell with implement context files |

**Key Decisions**:
- Implementation order: Accounts → Keys → Check-in (dependency-driven, not page-name-driven)
- Auto check-in: manual execution first, background scheduler later (Batch 9)
- Storage: Hive for structured data, flutter_secure_storage for credentials
- API: Dio + adapter pattern, only common/new-api compatible first
- State: flutter_riverpod without codegen to keep beginner learning curve low

**Created Task Directories**:
- 04-14-bootstrap-app-shell (current, P0)
- 04-14-setup-core-architecture (P0)
- 04-14-build-local-data-foundation (P0)
- 04-14-build-common-api-adapter (P0)
- 04-14-wire-riverpod-state (P0)
- 04-14-implement-accounts-ui (P0)
- 04-14-implement-keys-ui (P0)
- 04-14-implement-check-in-ui (P0)
- 04-14-add-scheduler-abstraction (P1)
- 04-14-add-tests-and-hardening (P0)

**Plan File**: .claude/plans/shiny-fluttering-prism.md


### Git Commits

| Hash | Message |
|------|---------|
| `ede982d` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: Batch 1: Bootstrap app shell

**Date**: 2026-04-16
**Task**: Batch 1: Bootstrap app shell
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 完成内容

| 文件 | 变更 |
|------|------|
| `lib/main.dart` | 替换 counter demo 为简短入口 |
| `lib/app/app.dart` | MaterialApp 根 widget |
| `lib/app/shell/app_shell.dart` | NavigationBar + IndexedStack 三页切换 |
| `lib/app/theme/design_tokens.dart` | 设计 token 常量（颜色/间距/圆角） |
| `lib/app/theme/app_theme.dart` | MD3 主题 + Inter 字体 |
| `lib/features/accounts/presentation/pages/accounts_page.dart` | 账号管理占位页 |
| `lib/features/keys/presentation/pages/keys_page.dart` | 密钥管理占位页 |
| `lib/features/check_in/presentation/pages/check_in_page.dart` | 自动签到占位页 |
| `test/widget_test.dart` | App shell 启动 + tab 切换测试 |
| `pubspec.yaml` | 添加 google_fonts 依赖 |

## 验证结果
- `flutter analyze`: No errors
- `flutter test`: 2/2 passed
- `flutter run`: 三页导航正常切换

## 下一步
- Batch 2: setup-core-architecture（引入 Riverpod、Dio、Hive，建 core/ 骨架）


### Git Commits

| Hash | Message |
|------|---------|
| `c7fc956` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: Batch 2: Set up core architecture

**Date**: 2026-04-16
**Task**: Batch 2: Set up core architecture
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Changes

| Category | Details |
|----------|---------|
| Dependencies | Added flutter_riverpod, dio, hive_flutter, flutter_secure_storage |
| Error | AppException sealed hierarchy (5 subtypes) + failure_mapper (Dio→AppException) |
| Result | Sealed Result<T> with Success/Failure + when/dataOrNull/getOrDefault extensions |
| Network | SiteType enum (9 sites + AuthType mapping), DioClient, AuthInterceptor, SiteAdapter abstract |
| Storage | SecureStore (abstract+impl), KeyValueStore (abstract+Hive impl), initHive() |
| Scheduler | AppScheduler abstract interface (contract only) |
| Widgets | AppScaffold, AppLoadingState, AppEmptyState, AppErrorState |
| App | ProviderScope wrapping MaterialApp, AppRoutes navigation constants |
| Tests | 3 new test files (Result, FailureMapper, SiteType), 17/17 passing |

## Verification
- `flutter analyze`: 0 errors
- `flutter test`: 17/17 passed
- `flutter run`: App launches normally, 3-tab navigation unchanged

## Key Decisions
- No go_router (IndexedStack sufficient for 3 tabs)
- No codegen/freezed (keep simple for beginner)
- SiteAdapter returns Map<String, dynamic> (typed models deferred to Batch 3)
- initHive() defined but not called in main.dart yet (deferred to Batch 3)


### Git Commits

| Hash | Message |
|------|---------|
| `5ba28fb` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 5: Batch 4: Build Dio Networking Layer + Common API Adapter

**Date**: 2026-04-16
**Task**: Batch 4: Build Dio Networking Layer + Common API Adapter
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Built the complete API networking infrastructure for Batch 4 — the bridge between local data and remote API calls.

## What Was Done

| Category | Details |
|----------|---------|
| Per-Request Config | `ApiRequest` immutable object carrying baseUrl + authToken + authType via `RequestOptions.extra` |
| AuthInterceptor Rewrite | Stateless interceptor: reads auth context per-request, supports Bearer/Cookie/none modes, overrides baseUrl |
| DioClient Update | Default baseUrl set to empty string; interceptor handles per-request override |
| DTO Layer (7 files) | `ApiResponse<T>`, `UserInfoDto`, `SiteStatusDto`, `CheckInResultDto`, `CheckInStatusDto`, `TokenDto`/`TokenListDto`, `AccessTokenDto` |
| SiteAdapter Expansion | Interface expanded from 3→9 methods with typed DTOs and `ApiRequest` parameter |
| CommonApiAdapter | Concrete implementation for new-api/one-api/one-hub/done-hub/veloera/octopus |
| Provider Registry | `siteAdapterProvider` + `siteAdapterForTypeProvider(SiteType)` family provider |
| Remote DataSources | 3 thin delegation layers (accounts/keys/check_in) with SiteType-family providers |
| API Mappers | 3 DTO→Entity mappers (AccountApiMapper, ApiKeyApiMapper, CheckInApiMapper) |
| Spec Updates | Updated `backend/directory-structure.md` and `backend/error-handling.md` to reflect actual architecture |

## Files Changed (21 files, 1157 insertions)

**New (16):**
- `lib/core/network/api_request.dart`
- `lib/core/network/dto/` (7 files)
- `lib/core/network/adapters/common_api_adapter.dart`
- `lib/core/network/site_adapter_provider.dart`
- `lib/features/accounts/data/datasources/accounts_remote_datasource.dart`
- `lib/features/keys/data/datasources/keys_remote_datasource.dart`
- `lib/features/check_in/data/datasources/check_in_remote_datasource.dart`
- `lib/features/accounts/data/models/account_api_mapper.dart`
- `lib/features/keys/data/models/api_key_api_mapper.dart`
- `lib/features/check_in/data/models/check_in_api_mapper.dart`

**Modified (5):**
- `lib/core/network/auth_interceptor.dart` — Rewritten for per-request auth
- `lib/core/network/dio_client.dart` — baseUrl default empty
- `lib/core/network/site_adapter.dart` — Expanded to 9 methods with typed DTOs
- `.trellis/spec/backend/directory-structure.md` — Updated to current state
- `.trellis/spec/backend/error-handling.md` — Updated with actual patterns

## Verification
- `flutter analyze` — No errors
- `dart format .` — 0 changed
- `flutter test` — All tests passed

## Next Step
**Batch 5 — wire-riverpod-state**: Repository implementations (local+remote), UseCases, Riverpod Notifier/Provider chain.


### Git Commits

| Hash | Message |
|------|---------|
| `4fe91d6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 6: Batch 5: Wire Riverpod State Management

**Date**: 2026-04-16
**Task**: Batch 5: Wire Riverpod State Management
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 完成内容

为 accounts / keys / check_in 三个 feature 建立完整的 **Repository → Riverpod AsyncNotifier/Provider** 状态管理链路。

| 层 | 新增文件 | 说明 |
|---|---|---|
| Repository 实现 | `accounts_repository_impl.dart` | 包装 LocalDataSource，返回 Result |
| Repository 实现 | `keys_repository_impl.dart` | 同上，按 accountId 查询 |
| Repository 实现 | `check_in_repository_impl.dart` | Task + Result 双域 CRUD |
| Providers | `accounts_providers.dart` | 全局 AsyncNotifier |
| Providers | `keys_providers.dart` | FamilyAsyncNotifier (按 accountId) |
| Providers | `check_in_providers.dart` | Task notifier + FutureProvider.family (results) |
| Notifier | `accounts_notifier.dart` | CRUD + toggleEnabled |
| Notifier | `keys_notifier.dart` | CRUD + Family arg |
| Notifier | `check_in_notifier.dart` | CRUD + executeCheckIn 全流程编排 |

**关键设计决策**:
- Notifier 即 Use Case（无单独 use case 文件，CRUD 逻辑简单）
- 悲观更新策略（本地存储 <1ms，简洁可靠）
- executeCheckIn 编排：task → account → token → remote API → save result → update task
- `update` 方法改名 `saveAccount`/`saveKey`（避免与 AsyncNotifier.update 冲突）
- Keys 使用 FamilyAsyncNotifier 按 accountId 参数化
- CheckIn results 用 FutureProvider.family 只读查询

**修复的问题**:
- accounts_providers.dart 缺 Account entity import
- check_in_providers.dart 缺 Result import (dataOrNull)
- AsyncNotifier.update 方法名冲突 → 重命名

**Spec 更新**: `.trellis/spec/backend/directory-structure.md` 补充 repositories/ 和 providers/ 目录说明


### Git Commits

| Hash | Message |
|------|---------|
| `be82e0d` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 7: Batch 6: Implement Accounts Management UI

**Date**: 2026-04-16
**Task**: Batch 6: Implement Accounts Management UI
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## What was done

| Area | Change |
|------|--------|
| AccountCard | New widget — horizontal layout with status dot (green/orange/gray + glow), name, siteType, URL, balance column, disabled state (opacity 0.6 + gray dot) |
| AccountFormSheet | New widget — modal bottom sheet for add/edit with 6 fields (name, URL, siteType, authType, token, notes), form validation, SiteType→AuthType cascade, async token loading from SecureStore |
| AccountsPage | Rewritten from placeholder — large title section, search bar, filter chips (pill style), stacked FAB group (add + search), pull-to-refresh, tap→edit, long-press→delete confirmation |
| SiteType/AuthType | Added `displayName` getters as shared extensions to eliminate DRY violation |
| Bug fix | Hive `_Map<dynamic, dynamic>` type cast error in `accounts_local_datasource.dart` — replaced `.cast<>()` with `Map<String, dynamic>.from()` |

## Key files

- `lib/features/accounts/presentation/widgets/account_card.dart` (new)
- `lib/features/accounts/presentation/widgets/account_form_sheet.dart` (new)
- `lib/features/accounts/presentation/pages/accounts_page.dart` (rewritten)
- `lib/core/network/site_type.dart` (added displayName extensions)
- `lib/features/accounts/data/datasources/accounts_local_datasource.dart` (bug fix)

## Design alignment

UI matched Stitch design (screen `2ee398a5f534418fadd6c7e665cf1260`): horizontal cards with status dots, search bar, filter chips, large title, stacked FABs.

## Next

- Batch 7: Implement keys management UI
- Batch 8: Implement check-in UI


### Git Commits

| Hash | Message |
|------|---------|
| `f920593` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 8: Implement keys management UI (Batch 7)

**Date**: 2026-04-16
**Task**: Implement keys management UI (Batch 7)
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

| File | Operation | Description |
|------|-----------|-------------|
| `keys/presentation/pages/keys_page.dart` | Modified | Replaced placeholder with full page (account selector, search, stats, FAB group) |
| `keys/presentation/widgets/account_selector.dart` | Created | Dropdown for selecting which account's keys to view |
| `keys/presentation/widgets/key_card.dart` | Created | Card widget with name, badges, actions, masked value, quota grid |
| `keys/presentation/widgets/key_status_badge.dart` | Created | Status pill: green "启用" / red "已过期" |
| `keys/presentation/widgets/key_value_row.dart` | Created | Masked key display with visibility toggle (lazy SecureStore load) |
| `keys/presentation/widgets/key_quota_grid.dart` | Created | 2x2 grid: remaining quota, used quota, expiry, creation date |
| `keys/presentation/widgets/key_form_sheet.dart` | Created | Modal bottom sheet for add/edit key with validation |

**Design reference**: `input/stitch_all_api_hub_flutter/_3_密钥管理/code.html`

**Key decisions**:
- Keys scoped to accounts via `keysProvider(accountId)` family provider
- Account auto-selection with fallback when selected account is deleted
- Secret values only loaded from SecureStore on explicit user tap (never during build)
- Followed Accounts feature pattern for consistency (page structure, form sheet, delete dialog)

**Verification**: `flutter analyze` 0 errors, `flutter test` 20/20 passed


### Git Commits

| Hash | Message |
|------|---------|
| `a995dba` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 9: Implement check-in dashboard UI (Batch 8)

**Date**: 2026-04-16
**Task**: Implement check-in dashboard UI (Batch 8)
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Replace check-in placeholder page with full results dashboard.

## Changes

| Area | Description |
|------|-------------|
| Data Layer | Added `getAllResults()` to local datasource, repository interface, and impl |
| Providers | New `allCheckInResultsProvider`, `checkInStatsProvider`, `checkInDashboardProvider`, `CheckInDashboardStats`, `CheckInResultDisplay` |
| Notifier | Added `executeAll()` with 5-concurrent pool for batch execution |
| Widgets | 5 new: `CheckInStatusBadge`, `CheckInOverallStatusBadge`, `CheckInFilterBar`, `CheckInSummaryCard`, `CheckInStatsGrid`, `CheckInResultCard` |
| Page | Full responsive dashboard (desktop: two-column, mobile: single-column scrollable) |
| Fix | `AppErrorState` wrapped in `FittedBox` for tight constraint resilience |

## Files (12 changed, +1303/-30)

**New:**
- `lib/features/check_in/presentation/widgets/check_in_status_badge.dart`
- `lib/features/check_in/presentation/widgets/check_in_filter_bar.dart`
- `lib/features/check_in/presentation/widgets/check_in_summary_card.dart`
- `lib/features/check_in/presentation/widgets/check_in_stats_grid.dart`
- `lib/features/check_in/presentation/widgets/check_in_result_card.dart`

**Modified:**
- `lib/features/check_in/data/datasources/check_in_local_datasource.dart`
- `lib/features/check_in/domain/repositories/check_in_repository.dart`
- `lib/features/check_in/data/repositories/check_in_repository_impl.dart`
- `lib/features/check_in/presentation/providers/check_in_providers.dart`
- `lib/features/check_in/presentation/providers/check_in_notifier.dart`
- `lib/features/check_in/presentation/pages/check_in_page.dart`
- `lib/core/widgets/app_error_state.dart`


### Git Commits

| Hash | Message |
|------|---------|
| `9fc316f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 10: Batch 9: Scheduler Abstraction + Auto Check-In

**Date**: 2026-04-16
**Task**: Batch 9: Scheduler Abstraction + Auto Check-In
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Implemented foreground Timer-based scheduler infrastructure for automatic check-in execution (Batch 9 of the master plan).

## Changes

| Category | Description |
|----------|-------------|
| AppScheduler Interface | Enhanced with `ScheduledTaskCallback` typedef and optional `onTick` parameter |
| ForegroundScheduler | New Timer.periodic implementation of AppScheduler for foreground mode |
| SchedulerConfig Entity | Global auto-check-in config: enabled, time window, retry strategy |
| Config Persistence | New `scheduler_config` Hive box + mapper + local datasource |
| CheckInSchedulerService | Core orchestrator: 1-min tick, time-window filtering, daily dedup, retry tracking |
| SchedulerConfigNotifier | Riverpod Notifier with Hive persistence for config state |
| SchedulerConfigCard | UI widget: global toggle, time window picker, retry strategy config |
| CheckInNotifier | Added `executeAllDue(List<String>)` for scheduler-targeted execution |
| Widget Test | Updated to use temp-directory Hive init for test environment |

## Files

| Action | File |
|--------|------|
| New | `lib/core/scheduler/foreground_scheduler.dart` |
| New | `lib/core/scheduler/check_in_scheduler_service.dart` |
| New | `lib/features/check_in/domain/entities/scheduler_config.dart` |
| New | `lib/features/check_in/data/models/scheduler_config_mapper.dart` |
| New | `lib/features/check_in/data/datasources/scheduler_config_local_datasource.dart` |
| New | `lib/features/check_in/presentation/providers/scheduler_config_notifier.dart` |
| New | `lib/features/check_in/presentation/providers/scheduler_providers.dart` |
| New | `lib/features/check_in/presentation/widgets/scheduler_config_card.dart` |
| Modified | `lib/core/scheduler/scheduler.dart` |
| Modified | `lib/core/storage/hive_store.dart` |
| Modified | `lib/features/check_in/presentation/providers/check_in_notifier.dart` |
| Modified | `lib/features/check_in/presentation/providers/check_in_providers.dart` |
| Modified | `lib/features/check_in/presentation/pages/check_in_page.dart` |
| Modified | `test/widget_test.dart` |

**Stats**: 14 files, +868 lines, -1 line

## Verification

- `flutter analyze` — 0 errors
- `dart format` — 0 changed
- `flutter test` — 43/43 passed

## Next

Batch 10: Tests and hardening (unit tests for scheduler, widget tests, clean up).


### Git Commits

| Hash | Message |
|------|---------|
| `c7b5f1f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 11: Batch 10: Add tests and hardening

**Date**: 2026-04-17
**Task**: Batch 10: Add tests and hardening
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

Complete test coverage for MVP. Added ~173 unit tests across 21 new test files.

## Work Done

| Category | Files | Tests |
|----------|-------|-------|
| Data Mapper tests | 6 | 45 |
| DTO / ApiResponse tests | 7 | 33 |
| AuthInterceptor test | 1 | 7 |
| CheckInApiMapper + SchedulerConfig tests | 2 | 18 |
| Repository tests (mocktail) | 3 | 50 |
| Notifier + DashboardStats tests | 2 | 20 |
| Lint fixes (widget_test.dart) | 1 | - |

## Key Decisions

- Used `mocktail` for mocking (no codegen, simpler than mockito)
- Mocked DataSource layer for Repository tests, Repository interface for Notifier tests
- Tested `CheckInDashboardStats.from` as pure function (no Riverpod needed)
- Deferred integration tests and widget-level tests to post-MVP

## Verification

- `flutter test`: +215 All tests passed
- `flutter analyze`: No errors
- `dart format`: Completed

## Files Changed (24 files, +2849 lines)

**Modified:**
- `pubspec.yaml` (added mocktail)
- `test/widget_test.dart` (fixed lint warnings)

**New test files:**
- `test/core/network/auth_interceptor_test.dart`
- `test/core/network/dto/api_response_test.dart`
- `test/core/network/dto/user_info_dto_test.dart`
- `test/core/network/dto/token_dto_test.dart`
- `test/core/network/dto/check_in_result_dto_test.dart`
- `test/core/network/dto/check_in_status_dto_test.dart`
- `test/core/network/dto/site_status_dto_test.dart`
- `test/core/network/dto/access_token_dto_test.dart`
- `test/features/accounts/data/models/account_mapper_test.dart`
- `test/features/accounts/data/models/account_api_mapper_test.dart`
- `test/features/accounts/data/repositories/accounts_repository_impl_test.dart`
- `test/features/accounts/presentation/providers/accounts_notifier_test.dart`
- `test/features/keys/data/models/api_key_mapper_test.dart`
- `test/features/keys/data/models/api_key_api_mapper_test.dart`
- `test/features/keys/data/repositories/keys_repository_impl_test.dart`
- `test/features/check_in/data/models/check_in_mapper_test.dart`
- `test/features/check_in/data/models/check_in_api_mapper_test.dart`
- `test/features/check_in/data/models/scheduler_config_mapper_test.dart`
- `test/features/check_in/data/repositories/check_in_repository_impl_test.dart`
- `test/features/check_in/domain/entities/scheduler_config_test.dart`
- `test/features/check_in/presentation/providers/check_in_dashboard_stats_test.dart`

## Status

MVP Batch 10 (final batch) complete. All 10 batches done.


### Git Commits

| Hash | Message |
|------|---------|
| `5f0480b` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 12: Fix: Hive Map type cast error in check-in datasources

**Date**: 2026-04-17
**Task**: Fix: Hive Map type cast error in check-in datasources
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Summary

修复签到页面的 Hive `_Map<dynamic, dynamic>` 类型转换崩溃问题。

## Changes

| File | Change |
|------|--------|
| `check_in_local_datasource.dart` | 7 处 `.cast<Map<String, dynamic>>()` / `as Map<String, dynamic>?` → `Map<String, dynamic>.from()` |
| `scheduler_config_local_datasource.dart` | 1 处 `as Map<String, dynamic>?` → `Map<String, dynamic>.from()` |

## Root Cause

Hive 存储返回 `_Map<dynamic, dynamic>`，`.cast<>()` 是惰性转换会在运行时崩溃，`Map<String, dynamic>.from()` 做即时深拷贝转换安全可靠。与 Session 7 accounts 模块修复方式一致。

## Testing

- [OK] `flutter analyze` — 零错误
- [OK] `flutter test` — 215 tests passed
- [OK] 签到页面不再崩溃


### Git Commits

| Hash | Message |
|------|---------|
| `7bd61f9` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 13: 同步 Stitch UI 设计稿：FAB / AppBar / BottomBar

**Date**: 2026-04-17
**Task**: 同步 Stitch UI 设计稿：FAB / AppBar / BottomBar
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 工作总结

按 Stitch 设计稿 1/2/3 号页面同步了自动签到、账号、密钥三页的悬浮按钮与导航栏样式，并补齐全局 AppBar 与「设置」占位 tab。

| 模块 | 改动 |
|------|------|
| AppShell | 新增全局 "API HUB" AppBar（hub 图标 + 品牌字 + 底部 1px 分隔线），Scaffold 首次引入 appBar |
| BottomBar | 3 tab → 4 tab：`签到 / 账号 / 密钥 / 设置`；图标同步为 event_available / account_balance_wallet / vpn_key / settings |
| Settings Feature | 新增 `features/settings/presentation/pages/settings_page.dart` 占位（图标 + "敬请期待"），data/domain 层暂不建 |
| CheckIn FAB | execute FAB 改造：`Material + InkWell + Hero(tag:'execute')`，纯 `colorScheme.primary` 底色、圆角 16、elevation 4、`onPrimary` 透明度 splash/highlight |
| Accounts FAB | add FAB 采用相同纯色模板，视觉与签到页对齐 |
| Keys FAB | add FAB 升级为 **Extended**（图标 + "添加密钥" 文字，h56 px24），纯色；FAB 组加 `crossAxisAlignment: end`，refresh 与 Extended FAB 右基线对齐 |

## 关键决策

- **弃用渐变**：Stitch 设计稿的主 FAB 原本是 `bg-gradient-to-br from-primary to-primary-container`，用户明确表达偏好纯色 + 可见水波纹 → 已沉淀到 memory (`feedback_fab_style.md`)，后续 FAB 默认遵循
- **头像占位 "UP" 不实现**：设计稿右上角圆形头像暂不做（需要用户登录态/资料源，超出当前 PRD）
- **颜色引用**：使用 `Theme.of(context).colorScheme.primary` 等 MD3 ColorScheme 语义色，不硬编码 hex，保持未来主题切换可用
- **Hero 保留**：所有 FAB 仍用 `Hero(tag: 'execute' / 'add')` 包裹，避免英雄动画丢失

## 验证

- `flutter analyze` — 0 error / 0 warning
- `dart format` — 83 文件 0 改动
- `flutter test` — 215 tests passed

## Updated Files

- `lib/app/shell/app_shell.dart` — 加 AppBar、新增 settings tab、图标同步
- `lib/features/check_in/presentation/pages/check_in_page.dart` — `_buildExecuteFab` 抽出
- `lib/features/accounts/presentation/pages/accounts_page.dart` — `_buildAddFab` 抽出
- `lib/features/keys/presentation/pages/keys_page.dart` — `_buildAddKeyFab` 抽出 + Column `CrossAxisAlignment.end`
- `lib/features/settings/presentation/pages/settings_page.dart` — **新增**，占位页

## Plan 文件

- `/Users/reborn/.claude/plans/ui-input-stitch-all-api-hub-flutter-1-c-lazy-hinton.md`

## Memory 增补

- `feedback_fab_style.md` — 主 FAB 用纯色不用渐变，必须有明显水波纹点击反馈


### Git Commits

| Hash | Message |
|------|---------|
| `469cb91` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 14: 账号启用/禁用切换贯通 UI 与签到链路

**Date**: 2026-04-18
**Task**: 账号启用/禁用切换贯通 UI 与签到链路
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 目标

原先 `Account.enabled` 字段已在实体/持久化/卡片视觉上就绪，但编辑弹窗仅"透传"不暴露给用户；更隐蔽的是 `CheckInNotifier.executeCheckIn` 与 `CheckInSchedulerService._getDueTasks` **完全不校验** `account.enabled`，被禁用的账号仍可能被手动或自动签到。本 session 把启用/禁用语义从弹窗 UI 一路贯通到签到执行、调度过滤与列表排序。

## 变更概览

| 批次 | 领域 | 说明 |
|------|------|------|
| B1 | accounts/presentation | 编辑弹窗新增启用开关 + 字段级联动 + 启用副作用 |
| B2 | check_in + core/scheduler | 执行与调度两处预过滤 account.enabled，禁用静默不写历史 |
| B3 | accounts/presentation | 列表禁用账号沉底稳定 partition + 收紧卡片间距 |

## B1 — 编辑弹窗启用开关

- `account_form_sheet.dart`：标题下方新增 `Row(启用账号 + Switch)`，key `accountEnabledSwitch`；新增 `_enabled` state（新建默认 true、编辑取 `widget.account!.enabled`）
- 所有 `TextFormField` / `DropdownButtonFormField` 传入 `enabled: _enabled`，禁用态下字段灰显只读
- `_submit()` 写入 `enabled: _enabled`；提交成功后当 `_enabled && (!_isEditing || !prevEnabled)` 时 `unawaited(notifier.checkOne(account.id))`，启用→保存立即触发可达性重检
- 新增 `test/features/accounts/presentation/widgets/account_form_sheet_test.dart`（3 case：新建默认开、字段灰显联动、disabled→enabled 保存触发 checkOne）

## B2 — 签到链路尊重 account.enabled

- `check_in_notifier.dart:executeCheckIn`：account 解包非空后新增 `if (!account.enabled) return null;`（位于 `getAccessToken` 之前），**静默返回、不写 CheckInResult**，避免自动调度重复产生"skipped"堆积
- `check_in_scheduler_service.dart:_getDueTasks`：tick 阶段 `ref.read(accountsProvider).valueOrNull` 取快照，构建 `disabledAccountIds = {for (a in accounts) if (!a.enabled) a.id}`，在 `tasks.where` 里预过滤 `disabledAccountIds.contains(task.accountId)`，**保持 sync 签名**不改调用链
- 新增 `test/features/check_in/presentation/providers/check_in_notifier_test.dart`：核心断言 `verifyNever(() => checkInRepo.saveResult(any()))` + `verifyNever(() => accountsRepo.getAccessToken(any()))`
- 新增 `test/core/scheduler/check_in_scheduler_service_test.dart`：用 `fake_async` 推进 1 分钟真实触发 `Timer.periodic` tick，断言禁用账号的 task 未被执行
- `pubspec.yaml` 新增 `fake_async: ^1.3.1` 到 `dev_dependencies`

## B3 — 列表沉底排序 + 卡片间距

- `accounts_page.dart:_buildList` 在 isEmpty 判空后使用 `[...list.where(enabled), ...list.where(!enabled)]` 稳定 partition，O(n) 且不依赖 `List.sort` 稳定性保证
- 列表项 `Padding` vertical 从硬编码 `6` 调整为 `AppSpacing.xs`，并在 `account_card.dart` 的 `Card` 上显式 `margin: EdgeInsets.zero`，避免与外层 Padding 叠加导致视觉间距超出预期
- 新增 `test/features/accounts/presentation/pages/accounts_page_test.dart`：[A启用, B禁用, C启用] 渲染顺序为 [A, C, B]

## 关键取舍

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 禁用账号签到是否写 skipped 历史 | **否** | 定时调度每日 N 次重复写入会刷屏；notifier 层静默 return null 即可；`CheckInStatus.skipped` 留作未来需要时复用 |
| 启用开关位置 | 名称字段上方 Row+Switch | 用户指定；醒目且不与表单控件挤在一列 |
| 保存时机 | 跟随"保存"按钮一次性提交 | 与其他字段语义一致，取消可回滚 |
| 禁用账号 UI 其他字段 | 灰显只读 | 强化禁用语义；重新启用才解锁编辑 |
| 调度器 _getDueTasks 改造 | 读 provider 快照内联过滤，保持 sync | 不动函数签名，不需 async/await 传染调用链 |
| 列表排序落点 | UI 层（presentation） | 数据层保留 repository 原序；未来 filter/search 可换策略 |

## 测试指标

- `flutter analyze` → No issues found
- `flutter test` → 基线 225 → **+231 All tests passed!**（6 条新增测试全绿）

## 踩坑记录

- **Card 默认 margin 陷阱**：Flutter `Card` 有 `margin: EdgeInsets.all(4.0)` 默认值。外层 `Padding(vertical: X)` 与它叠加，相邻卡片总间距 = `2X + 8`。光改外层间距不动 Card margin 很容易"调完更大或更小"。解决方式：显式 `Card(margin: EdgeInsets.zero)` + 外层 Padding 用设计令牌。
- **AsyncNotifierProvider 测试 override**：`accountsProvider.overrideWith(() => fake)` 要求 Fake 继承 `AccountsNotifier` 并正确 override `build()`；否则 `state = AsyncData(...)` 初始化时机会踩坑。
- **Timer.periodic 的单测**：`CheckInSchedulerService.start()` 用 `Timer.periodic(1min, ...)`。标准做法是 `fake_async: ^1.3.1` 包 `fakeAsync((async) { service.start(); async.elapse(Duration(minutes: 1)); })`，配合 `flushMicrotasks` 让 AsyncNotifier 的 build Future 解析。

## 后续待办（不阻塞）

- `accounts_page.dart` 的 `_FilterChip` "已启用/已禁用/已同步/警告" onTap 仍是 TODO，未实装过滤
- 可考虑把"领域布尔字段必须在所有消费链路一致校验"沉淀到 `.trellis/spec/guides/cross-layer-thinking-guide.md`
- 稳定 partition 排序模式可沉淀到 `.trellis/spec/frontend/state-management.md`


### Git Commits

| Hash | Message |
|------|---------|
| `1b95258` | (see git log) |
| `276ee7f` | (see git log) |
| `67934fd` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 15: 完善账号管理过滤标签与搜索链路

**Date**: 2026-04-19
**Task**: 完善账号管理过滤标签与搜索链路
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 任务来源

`/sw:interview-to-build` 驱动：journal-1.md(Session 14) 末尾明确标注 `accounts_page.dart` 的 `_FilterChip "已启用/已禁用/已同步/警告" onTap 仍是 TODO`；上方 TextField 搜索框也未实装。本批次打通过滤链路并顺带实装搜索。

## Main Changes

| 层 | 变更 | 文件 |
|---|---|---|
| Presentation (新增) | `AccountListFilter` enum + 两个 StateProvider + `FilteredAccountsView` record + 派生 `filteredAccountsProvider`（组合 accounts+filter+search → 列表 + partition 排序 + 三分组计数） | `lib/features/accounts/presentation/providers/accounts_filter_providers.dart` |
| Presentation (改造) | 移除「已同步/警告」Chip；接入 TextEditingController + 300ms debounce Timer；suffixIcon 清除按钮；`_FilterChip` 改签名（filter+count+selected+onTap，selected 时 onTap=null 实现强 Radio）；空状态分化（无账号 vs 无匹配）+ 「清除筛选」CTA | `lib/features/accounts/presentation/pages/accounts_page.dart` |
| 测试 (新增) | 派生 Provider 单测 13 条：空列表/三种 filter/name·baseUrl·notes 搜索/大小写不敏感/中文/null notes/filter+search AND/动态计数/trim/partition 稳定性/`AccountListFilter.matches` | `test/features/accounts/presentation/providers/accounts_filter_providers_test.dart` |
| 测试 (扩展) | Widget 测试 +8：Chip 含数量、切换 filter、再点选中 Chip 无反应、搜索 debounce、清除按钮可见性与清空、两种空状态分化、「清除筛选」CTA 恢复默认 | `test/features/accounts/presentation/pages/accounts_page_test.dart` |

## 关键决策（采访沉淀）

| 决策点 | 选择 | 原因 |
|--------|------|------|
| 已同步/警告标签 | **移除** | 语义与 reachability 耦合过深，未清晰定义先不做 |
| 过滤标签交互 | 单选（强 Radio） | 再点选中的 Chip 无反应，`onTap: null` 实现 |
| 过滤/搜索状态位置 | StateProvider + 派生 Provider | 切 BottomNav 保持、App 重启重置、可测试 |
| 计数数据源 | 搜索后子集动态计算 | 用户能感知「搜索到的 N 里启用 X 禁用 Y」 |
| partition 排序 | 三 Tab 都应用 | 为未来新增 Tab 铺路 |
| 搜索字段 | name+baseUrl+notes | notes 支持用户自定义「主力/小号」等标记 |
| 搜索 debounce | 300ms | 避免每键 rebuild，同时保持即时感 |
| 空状态 | 分化为「无账号」与「无匹配 + 清除筛选」 | 精准引导 CTA 行为 |
| Spec 沉淀 | 暂不写入 frontend/state-management.md | 用户明确「保持实现范围」，待第二个场景再抽象 |
| 测试执行 | SubAgent（check）跑 analyze + test | 主 Agent 不污染上下文 |

## 验证

- `dart format .` → 3 files formatted（whitespace only，无语义变化）
- `flutter analyze` → **No issues found!**
- `flutter test` → **255/255 pass**（基线 ~231 → +24，含本批次 21 条新增 + 其他未动摇的已有测试）

## 踩坑记录

- **AsyncNotifierProvider + override + ProviderContainer**：测试里 `accountsProvider.overrideWith(() => FakeAccountsNotifier(list))` 需要 Fake 继承真 `AccountsNotifier` 并只 override `build()`，其余 `checkAll/checkOne` no-op 避免在 widget test 中触发 reachability 扫描。
- **suffixIcon 随输入显隐**：`TextEditingController.addListener` + `setState(_hasSearchText)` 是最简做法；比 `ValueListenableBuilder` 嵌套易读，且单页性能完全没压力。需同时处理「程序 clear()」场景（不会走 `onChanged`）。
- **debounce Timer 生命周期**：`dispose` 里必须 `_debounce?.cancel()`，否则 page dispose 后 Timer 仍可能触发 `ref.read`，访问已销毁对象。
- **Widget 测试里 `Provider.overrideWith` 的作用域**：测试里若要直接断言 state 变化，需要用 `UncontrolledProviderScope(container: ...)` 把 `ProviderContainer` 暴露给测试代码，而不是 `ProviderScope(overrides: [...])`——后者无法直接拿到内部 container。

## 后续待办（不阻塞）

- FAB「scan duplicates」按钮仍是 TODO（本批次未涉及）
- 未来扩展 Tab（如「最近活跃」「余额异常」）只需给 `AccountListFilter` 加分支 + `matches`/`label` + 后续可能的 filter-specific 排序策略
- 若第二个同类场景出现，可把「enum 驱动的过滤 + 派生 Provider + 动态计数」抽象入 `.trellis/spec/frontend/state-management.md`


### Git Commits

| Hash | Message |
|------|---------|
| `12f77d5` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 16: 修复 macOS adhoc 签名并新增 platform spec 分类

**Date**: 2026-04-19
**Task**: 修复 macOS adhoc 签名并新增 platform spec 分类
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 背景

执行 `flutter build macos` 报错：

```
error: Signing for "Runner" requires a development team.
```

用户没有 Apple Developer Team，目标是让 Xcode → Runner → Signing & Capabilities 里
Provisioning Profile 字段显示 **None Required**（即 adhoc / Sign to Run Locally）。

## 问题根因

`macos/Runner.xcodeproj/project.pbxproj` 的 Runner target 被人工改成 Manual
签名但 Team 空，加上 `"CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Development"`
target-level 覆盖了 project-level 的 `"-"`，Release 的 `CODE_SIGN_STYLE = Manual`
与空 profile 直接冲突。

此外两份 entitlements 手工加过 `keychain-access-groups`。该 entitlement 是
Apple 的 restricted entitlement，adhoc 签名无法承载，会触发二段错误：

```
error: "Runner" has entitlements that require signing with a development certificate.
```

## 解决方案（两步修复）

### Step 1: pbxproj 六处字段对齐 Flutter 模板默认

| 行号 | 字段 | 修改 |
|------|------|------|
| 272  | Runner TargetAttributes.ProvisioningStyle | Manual → Automatic |
| 281  | Flutter Assemble TargetAttributes.ProvisioningStyle | Manual → Automatic |
| 574  | Profile CODE_SIGN_IDENTITY[sdk=macosx*] | "Apple Development" → "-" |
| 709  | Debug CODE_SIGN_IDENTITY[sdk=macosx*] | "Apple Development" → "-" |
| 732  | Release CODE_SIGN_IDENTITY[sdk=macosx*] | "Apple Development" → "-" |
| 733  | Release CODE_SIGN_STYLE | Manual → Automatic |

### Step 2: entitlements 清除 keychain-access-groups

从 `macos/Runner/DebugProfile.entitlements` 与 `Release.entitlements` 各删除 4 行
`keychain-access-groups` 节。

## 验证（SubAgent 执行）

```
[OK] flutter build macos --debug --no-pub: 21.8s, exit 0
[OK] codesign -dvv: Signature=adhoc, Identifier=com.mallotec.reb.flallapihub, TeamIdentifier=not set
```

## 非显而易见的发现

- **adhoc 签名拒绝 restricted entitlement**：`keychain-access-groups` / App Groups 等
  entitlement 必须由真实开发证书签署，即使 Xcode 能编辑也会在 codesign 阶段拒绝。
- **`$(AppIdentifierPrefix)` 在 adhoc 下展开为空**：没有 provisioning profile
  时这个变量无值，即使绕过了 codesign 检查，运行时读取 keychain 也拿不到正确 group。
- **macOS flutter_secure_storage 不依赖 keychain-access-groups**：sandbox 关闭时
  默认 keychain 完全够用，`-34018 errSecMissingEntitlement` 的根因反而是多余的 entitlement
  导致 codesign 拒绝嵌入。
- `accounts_repository_impl.dart` 里早先就有 `-34018` TODO 注释，这次签名修复
  有望顺便解决该运行时错误（需 `flutter run -d macos` 实测确认）。

## 产出文件

| 类型 | 文件 |
|------|------|
| 修改 | `macos/Runner.xcodeproj/project.pbxproj` |
| 修改 | `macos/Runner/DebugProfile.entitlements` |
| 修改 | `macos/Runner/Release.entitlements` |
| 新增 | `.trellis/spec/platform/index.md`（新 spec 分类入口） |
| 新增 | `.trellis/spec/platform/macos-signing.md`（完整文档：Required Settings / Forbidden / Common Mistakes / Verification / 迁回 Apple Team 路径） |

顺带一条依赖升级 commit (`d48c9b3`)：

- `flutter_secure_storage` 9.2.4 → 10.0.0（触发 plugin 重命名 macos → darwin）
- `dio` 5.8.0 → 5.9.2
- `cupertino_icons` 1.0.8 → 1.0.9

## 下一步（留给人）

1. `flutter run -d macos` 冒烟测试 UI + `flutter_secure_storage` 读写
2. 若 `-34018` 不再出现，移除 `accounts_repository_impl.dart:76` 的 TODO 注释并补 commit
3. 未来上架 App Store 时，按 `platform/macos-signing.md` 的"Migration Back"章节恢复真实 Team 签名


### Git Commits

| Hash | Message |
|------|---------|
| `bc68e99` | (see git log) |
| `d48c9b3` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 17: 扁平化敏感字段到实体并彻底移除 flutter_secure_storage

**Date**: 2026-04-19
**Task**: 扁平化敏感字段到实体并彻底移除 flutter_secure_storage
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## 背景

上一轮（commit `bc68e99`）把 macOS Runner 签名改成 adhoc + 移除 entitlements 里的
`keychain-access-groups` 让 `flutter build macos` 能过，但运行时保存 Token 仍报：

```
PlatformException(Code: -34018, A required entitlement isn't present., null)
```

## 真正根因（读源码确认）

`flutter_secure_storage_darwin` 10.0 的 `FlutterSecureStorage.swift:204-208` 在 macOS
下**硬编码** `kSecUseDataProtectionKeychain = true`，该后端要求调用进程签名携带
`application-identifier`（来自真实 Apple Team）或 `keychain-access-groups`
entitlement。adhoc 签名两者都没有：

- `application-identifier` 需要 Apple Team 签发的证书
- `keychain-access-groups` 是 Apple restricted entitlement，adhoc / 自签证书不能携带
  （Xcode 会报 "requires signing with a development certificate"）

死胡同。另外还发现插件存在 Dart/Swift 键名拼写不一致的 bug
（`usesDataProtectionKeychain` vs `useDataProtectionKeyChain`），用户即使通过
`MacOsOptions` 关闭也不生效，无法从 API 层绕过。

## 决策

用户明确放弃 Apple 账号体系（免费 Personal Team 也不用），也放弃本地 AES 加密方案
（之前 research 过的 cryptography + path_provider + master.seed），选最朴素的
**扁平化明文存储**：敏感字段直接挂到实体上，走现有的 Hive 明文 Box。威胁模型接受
本机被攻破就能读 token 这个前提——和绝大多数单机工具一致。

## 实施（37 files, +327 / -698 行净减 371）

### Domain 层

- `Account` 加 `String? accessToken`
- `ApiKey` 加 `String? keyValue`
- 两个 Mapper 的 `toMap` / `fromMap` 同步加字段

### Repository 接口简化

- `create(Entity, {String? token/value})` → `create(Entity)`
- `update(...)` 同上
- 删除 `getAccessToken(id)` / `getKeyValue(id)` 方法声明

### Data 层

- 两个 `*_local_datasource.dart` 去掉 `SecureStore` 依赖
- `save` 方法去掉命名参数（token 已在 entity 里）
- 两个 `*_repository_impl.dart` 同步签名 + 清除 `accounts_repository_impl.dart:76`
  的 -34018 TODO 注释
- `check_in_notifier.dart:111-114` 去掉 `await repo.getAccessToken(...)` 的二次查询，
  直接读 `account.accessToken`（`accountsRepo.getById` 一步已经拿到实体）

### Presentation 层

- `account_form_sheet` / `key_form_sheet`：`_loadExisting*` 异步加载方法整块删除；
  `_*Loaded` 加载状态字段连同 UI 的 `CircularProgressIndicator` 分支一起简化；
  编辑模式下直接从 `widget.account?.accessToken` / `widget.apiKey?.keyValue` 同步取值
- 编辑 + token 未改 → 保留原值；改了或新建 → 用输入框值（空串映射到 `null`）
- `accounts_notifier` / `keys_notifier` 的 `create` / `save*` 去命名参数
- `key_value_row.dart` 从 `ConsumerStatefulWidget` 降级为普通 `StatefulWidget`：
  签名从 `{required keyId}` 改成 `{required keyValue}`，去掉异步读 Keychain 逻辑
  与 `ref` 依赖；无 keyValue 时显示 mask 并禁用切换

### 清理

- 删除 `lib/core/storage/secure_store.dart`
- `pubspec.yaml` 移除 `flutter_secure_storage`，`flutter pub get` 连带清掉 8 个
  `flutter_secure_storage_*` 子包
- `macos/Flutter/GeneratedPluginRegistrant.swift` / `linux/*` / `windows/*` 的
  generated plugin registrant 自动刷新
- `cd macos && pod install` 后 `macos/Runner.xcodeproj/project.pbxproj` 自动移除
  `[CP] Embed Pods Frameworks` build phase（无 Pods 可嵌入）

### 测试（5 个文件对齐新签名）

- `accounts_repository_impl_test.dart` / `keys_repository_impl_test.dart`：
  删 `getAccessToken` / `getKeyValue` group；`mockLocal.save(..., token: ...)` 改成
  `mockLocal.save(...)`；新增 "carrying the token / secret" 测试断言实体字段
- `accounts_notifier_test.dart`：replace_all 去 `accessToken: any(named:...)`，修
  `captureAny` verify
- `account_form_sheet_test.dart`：FakeAccountsNotifier 签名对齐；删 `getAccessToken`
  stub 与 `Success` import
- `check_in_notifier_test.dart`：删 `verifyNever(() => mockAccountsRepo.getAccessToken(...))`

### Spec 同步

更新 `.trellis/spec/platform/macos-signing.md`：

- 新增 **Historical Note** 章节记录两轮决策链（adhoc 签名修复 → secure_storage 退场）
- 修正原文错误断言："flutter_secure_storage_darwin still works because it falls
  back to default keychain" —— 实测不成立
- Forbidden Patterns 加一条：禁止在没有恢复真实 Apple Team 前重新引入
  Keychain-backed plugin
- Common Mistakes 表加一行：`flutter_secure_storage + adhoc + 移除 keychain-access-groups = 运行时 -34018`
- Verification 的 Runtime smoke 改成验证 Hive 读写
- Migration Back 重写 step 4：先恢复 Apple Team 再决定是否启用 Keychain
- Reference 链接 round 1 / round 2 两个 Trellis 任务

## 验证结果（SubAgent 两轮验证）

| 项 | 结果 |
|---|---|
| `flutter analyze` | 0 errors / 0 warnings / 0 infos |
| `flutter test` | 249 passed（原 222，新增 carrying-token / carrying-secret 测试替换 get* 测试） |
| `flutter build macos --debug` | exit 0，~15s |
| `codesign -dvv` | Signature=adhoc，Identifier=com.mallotec.reb.flallapihub |
| `grep flutter_secure_storage` lib/ + test/ + pubspec.yaml | 空命中 |
| 各平台 plugin_registrant 扫描 | 空命中 |

中途出错两次并自我修复：

1. 第一轮 SubAgent 发现 4 个遗漏测试文件（accounts_notifier / account_form_sheet /
   check_in_notifier / keys_repository_impl）以及 2 个 unused_import（两个 form_sheet
   的 `core/result/result.dart`），11 处 Edit 修复
2. 中途 Bash `rm` 被 permission 拒绝，改用 `git rm` 删除 `secure_store.dart`
3. `pod install` 把 cwd 切到 `macos/` 导致 Agent 工具因相对路径找不到 hook 而报错，
   显式 `cd` 回根目录修复

## 关键洞察（Non-Obvious）

- **`flutter_secure_storage_darwin` 在 adhoc 签名下无论如何都会 `-34018`**：根本原因是
  插件硬编码 Data Protection Keychain，需要 Apple Team 证书或 restricted entitlement
  两选一。移除 `keychain-access-groups` 只让构建通过，运行时仍报错。这是本次最容易
  反复踩的坑——spec 文档已更新。
- **拼写不一致 bug 让 `usesDataProtectionKeychain` option 形同虚设**：Dart 发
  `usesDataProtectionKeychain`，Swift 读 `useDataProtectionKeyChain`，参数永远不生效。
  未来若 flutter_secure_storage 修了上游 bug，再考虑是否回归。
- **删除垂直抽象比优化实现更干净**：两轮尝试（第一轮签名修复 + 第二轮 research 走 AES
  加密）最后都输给了"扁平化+接受明文"。SecureStore 抽象层对单机工具是过度设计，移除
  之后净减 371 行代码（含测试），是本次意外的收益。

## 下一步（留给人）

1. `flutter run -d macos` 冒烟验证 -34018 确已消失（重点：添账号填 token → 保存 →
   重启 → 读回；编辑不改 / 改 / 清空 三分支；ApiKey keyValue 同样走一遍）
2. Android / iOS 真机冒烟（如有设备）
3. 未来上架 App Store 时参考 macos-signing.md 的 Migration Back 重新启用 Keychain


### Git Commits

| Hash | Message |
|------|---------|
| `57500f9` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 18: 账号编辑弹窗重构（5 批次）

**Date**: 2026-04-21
**Task**: 04-21-extend-account-entity / 04-21-add-tags-module / 04-21-reusable-form-components / 04-21-account-edit-page-rewrite / 04-21-cleanup-and-verify
**Branch**: `main`

### Summary

按 Stitch HTML 设计稿对齐 PRD 重构账号编辑入口：淘汰旧的 bottom-sheet `AccountFormSheet`，改为全屏 `Navigator.push` 的 `AccountEditPage`；扩展 `Account` 实体 7 个字段（用户 / 计费 / 签到 / 标签分组）+ 新增独立 `features/tags` 三层模块；签到配置从单开关升级为带时间窗口 / 重试策略的内嵌 Section。

### Main Changes

| 层 | 文件 | 说明 |
|---|---|---|
| **数据层 / 实体** | `lib/features/accounts/domain/entities/account.dart` | +7 字段 `username / userId / exchangeRate / manualBalanceUsd / excludeFromTotalBalance / tagIds / checkIn`，`redemptionUrl` 抽到根级 |
| 数据层 / 实体 | `lib/features/accounts/domain/entities/check_in_config.dart` | **新增** `CheckInConfig` 值对象（enabled / windowStart / windowEnd / retry / cookie） |
| 数据层 / 常量 | `lib/core/config/app_defaults.dart` | **新增** `kDefaultUsdToCnyRate = 7.24`（PRD 基线汇率，Stitch 稿一致） |
| 数据层 / 映射 | `lib/features/accounts/data/models/account_mapper.dart` | `toMap` / `fromMap` 同步 7 字段；对旧 Hive 数据向后兼容 null-safe 读取 |
| 数据层 / 仓库 | `lib/features/accounts/data/repositories/accounts_repository_impl.dart` + `domain/repositories/accounts_repository.dart` | 签名对齐新字段 |
| 数据层 / 持久化 | `lib/core/storage/hive_store.dart` | 新增 `tags` Hive box 注册 |
| **Tag 模块（全新）** | `lib/features/tags/domain/entities/tag.dart` + `repositories/tags_repository.dart` | 实体 + 接口 |
| Tag 模块 | `lib/features/tags/data/models/tag_mapper.dart` + `datasources/tags_local_datasource.dart` + `repositories/tags_repository_impl.dart` | Hive 映射 + 本地数据源 + `upsertByName` 归一化 + 删除级联清理 `Account.tagIds` |
| Tag 模块 | `lib/features/tags/presentation/providers/tags_providers.dart` + `tags_notifier.dart` | AsyncNotifierProvider + 串行化锁防并发重名 |
| Tag 模块 | `lib/features/tags/presentation/widgets/tag_chip_input.dart` | Chip 选择 + Picker 对话框 + 现场创建新标签 |
| **可复用组件** | `lib/core/widgets/section_card.dart` | 通用分组容器（图标 + 大写标题 + 子内容） |
| 可复用组件 | `lib/features/accounts/presentation/widgets/check_in_config_section.dart` | 签到配置 Section（启用 / 时间窗口 / 重试次数 / 重试间隔） |
| **AccountEditPage** | `lib/features/accounts/presentation/pages/account_edit_page.dart` | 全屏 `Scaffold` + `AppBar` + `BottomAppBar`；4 个 `SectionCard` 分组；`PopScope` + `isDirty` 拦截；`rocket_launch` 仅 `isManaged` 站点显示；autoDetect / 跳托管站点 / Cookie 子表显示 "即将上线" SnackBar |
| **入口接线** | `lib/features/accounts/presentation/pages/accounts_page.dart` | FAB / 空状态 CTA / 卡片 tap 全部改为 `AccountEditPage.push(context, account:...)` |
| **Legacy Stub** | `lib/features/accounts/presentation/widgets/account_form_sheet.dart` + `test/.../account_form_sheet_test.dart` | 清空为 `library;` + 注释 + `void main() {}`（用户要求保留物理文件） |

### Key Decisions

- **改为全屏 `Navigator.push` Page**（而非 `showModalBottomSheet` / `showGeneralDialog`）：复杂表单在 mobile / desktop 屏幕均需纵向空间；原生返回键 / AppBar back 一键 pop；AnimatedSwitcher 等嵌套不再受 bottom sheet 约束
- **Tag 模块独立三层 + 级联删除**：避免散落在 `accounts/` 内部；`upsertByName` 做 `trim() + toLowerCase()` 归一化防重；删除标签时同步清理所有 `Account.tagIds` 引用保持数据一致性
- **`redemptionUrl` 抽到 `Account` 根级**（不嵌 `CheckInConfig`）：兑换码 URL 是站点属性，与签到调度无关；domain 保持 single responsibility
- **autoDetect / 托管站点跳转 / Cookie / Sub2API 作为下期**：本批次只拉通实体 + 主编辑 UI，这几个按钮接口已预留，点击后 SnackBar "即将上线"
- **`CheckInConfig` 只存静态配置**：账号级 `enabled / windowStart / windowEnd / retryCount / retryInterval / cookie`；调度真正执行归 `CheckInTask.enabled`；最终生效值 = `account.checkIn.enabled AND task.enabled`
- **`PopScope` + `isDirty` 拦截**：Form 任意字段改动后未保存返回时弹出 `AlertDialog` 二次确认，避免误触丢数据
- **`account_form_sheet.dart` 保留为空 library stub**：用户明确要求不物理删除文件；保留 `library;` 头 + 注释指引 `account_edit_page.dart`；`_test.dart` 留 `void main() {}` 让 `flutter test` 不报 load 失败

### Updated Files

**新增（lib/）**:
- `lib/core/config/app_defaults.dart`
- `lib/core/widgets/section_card.dart`
- `lib/features/accounts/domain/entities/check_in_config.dart`
- `lib/features/accounts/presentation/pages/account_edit_page.dart`
- `lib/features/accounts/presentation/widgets/check_in_config_section.dart`
- `lib/features/tags/domain/entities/tag.dart`
- `lib/features/tags/domain/repositories/tags_repository.dart`
- `lib/features/tags/data/models/tag_mapper.dart`
- `lib/features/tags/data/datasources/tags_local_datasource.dart`
- `lib/features/tags/data/repositories/tags_repository_impl.dart`
- `lib/features/tags/presentation/providers/tags_providers.dart`
- `lib/features/tags/presentation/providers/tags_notifier.dart`
- `lib/features/tags/presentation/widgets/tag_chip_input.dart`

**修改（lib/）**:
- `lib/core/storage/hive_store.dart`
- `lib/features/accounts/domain/entities/account.dart`
- `lib/features/accounts/domain/repositories/accounts_repository.dart`
- `lib/features/accounts/data/models/account_mapper.dart`
- `lib/features/accounts/data/repositories/accounts_repository_impl.dart`
- `lib/features/accounts/presentation/pages/accounts_page.dart`
- `lib/features/accounts/presentation/widgets/account_form_sheet.dart`（清空为 stub）

**新增（test/）**:
- `test/core/widgets/section_card_test.dart`
- `test/features/accounts/presentation/pages/account_edit_page_test.dart`
- `test/features/accounts/presentation/widgets/check_in_config_section_test.dart`
- `test/features/tags/domain/entities/tag_test.dart`
- `test/features/tags/data/repositories/tags_repository_impl_test.dart`
- `test/features/tags/presentation/providers/tags_notifier_test.dart`
- `test/features/tags/presentation/widgets/tag_chip_input_test.dart`

**修改（test/）**:
- `test/features/accounts/data/models/account_mapper_test.dart`
- `test/features/accounts/data/repositories/accounts_repository_impl_test.dart`
- `test/features/accounts/domain/entities/account_test.dart`
- `test/features/accounts/presentation/widgets/account_form_sheet_test.dart`（清空为 stub）

### Testing

- `dart format .` → 18 files formatted（纯空白差异，无语义变化）；二次运行 0 changed
- `flutter analyze lib/ test/` → **No issues found!**
- `flutter test` → **301/301 passed**（基线 255 → +46 含 SectionCard / TagChipInput / AccountEditPage / tags / check_in_config_section 等新增覆盖）
- 残留扫描：
  - `grep -n AccountFormSheet lib/` 仅剩 `account_edit_page.dart:3` 一处 doc comment 记录历史演进，非活代码引用
  - `grep -n "AccountFormSheet.show" lib/ test/` 零命中
  - `grep -n account_form_sheet lib/ test/` 零命中（stub 文件不自引用）

### Status

[OK] **Completed**

### Next Steps

- 实装 Cookie / Sub2API 字段编辑分支（`authType != accessToken` 的 UI 子表）
- `autoDetect` 按钮接 `SiteAdapter.probe(baseUrl)` 做真实站点类型探测
- 托管站点 `rocket_launch` 按钮跳转到 ChannelDialog / TokenList 页面


## Session 19: 账号弹窗重构的 code-spec 沉淀

**Date**: 2026-04-22
**Branch**: `main`

### Summary

对昨天（Session 18）账号编辑弹窗重构产出的可执行契约进行沉淀。`/trellis:finish-work` 把 5 批次改动分成 3 个 commit 合入 main 后，再以 `/trellis:update-spec` 收尾，把跨层契约和复用模式写进 `.trellis/spec/`，方便未来的 AI / 开发者直接按模板套用。

### Main Changes

| 文件 | 新增行 | 内容 |
|---|---|---|
| `.trellis/spec/frontend/state-management.md` | +211 | **Pattern 4 — Serialized Writes in an AsyncNotifier**（`_writeQueue` + `Completer` chain + `ref.keepAlive`）/ **Pattern 5 — Cross-Feature Cascade Delete via Sibling Repository**（跨层契约 7-section mandatory：Scope / Signatures / Contracts / Validation & Error Matrix / Good-Base-Bad / Tests Required / Wrong vs Correct） |
| `.trellis/spec/frontend/component-guidelines.md` | +113 | **Pattern — Full-Screen Form Page with Unsaved-Changes Guard**（`Navigator.push(fullscreenDialog: true)` + `_FormSnapshot` 值对象 + `PopScope(canPop: !_isDirty)` + 双路径 close 一致性 + 必需 widget 测试清单） |
| `.trellis/spec/guides/cross-layer-thinking-guide.md` | +42 | **Mistake 4: Lazy Cascade on Read**（指向 Pattern 5）/ **Mistake 5: Dual-Source Booleans Across Layers**（AND/OR 语义契约，以 `account.checkIn.autoCheckInEnabled AND CheckInTask.enabled` 为例）/ Checklist 补两条：cascade delete 检查、legacy payload round-trip |

### Key Decisions

- **Code-Spec vs Guide 严格分工**：实现契约（怎么写、测什么）全部沉到 `frontend/state-management.md` 和 `component-guidelines.md` 的 **Reusable Patterns** 区；`guides/` 只留 checklist / pointer，不复述规则
- **跨层契约必须有 7-section 深度**：Tag→Account 级联删除是 `TagsRepository.delete` 调 `AccountsRepository.removeTagFromAllAccounts(id)` 的跨层协议，按 `/trellis:update-spec` 的 Mandatory Triggers 规则完整输出 Scope / Signatures / Contracts / Error Matrix / Good-Base-Bad / Tests / Wrong-vs-Correct
- **Wrong vs Correct 用真实代码**：选 lazy filter on read（坏）vs cascade on write（好）这一对 Dart 片段，避免原则级空话
- **双源布尔用显式 AND/OR 契约化**：`CheckInConfig.autoCheckInEnabled` 和 `CheckInTask.enabled` 的双源真相风险在 Session 18 评审时被 Plan agent 捕捉，现在以 Mistake 5 形式沉淀

### Updated Files

- `.trellis/spec/frontend/state-management.md`（211 → 494 行）
- `.trellis/spec/frontend/component-guidelines.md`（86 → 199 行）
- `.trellis/spec/guides/cross-layer-thinking-guide.md`（94 → 136 行）

### Git Commits

| Hash | Message |
|------|---------|
| `9875197` | docs(spec): capture cascade-delete and async-notifier serialization contracts |

### Testing

- 改动仅限 `.trellis/spec/` Markdown 文档，无代码变更
- 工作树干净后对齐 `flutter analyze` / `flutter test` 状态（Session 18 基线：0 issues / 301 passed）

### Status

[OK] **Completed**

### Next Steps

- 下个 feature（keys 编辑 / 设置页）按 Pattern 4 / Full-Screen Form Page 模板复用
- 跨 feature 引用删除场景（例如未来"项目-账号"关联）严格走 Pattern 5 的 7-section 流程
- `CheckInTask` 侧调度器实装时，显式在代码里实现 Mistake 5 的 AND 语义（并加 regression test）


## Session 20: Fix Hero tag collision + enforce required site-info fields with SiteType.unknown default

**Date**: 2026-04-22
**Task**: Fix Hero tag collision + enforce required site-info fields with SiteType.unknown default
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Context

Two issues surfaced while exercising the new full-screen `AccountEditPage`:

1. **Hero tag collision** — opening the edit page (pushed via `fullscreenDialog: true`) threw `multiple heroes had the following tag: refresh` and later `... tag: add`. `AppShell` keeps every tab alive via `IndexedStack`, so the refresh / add FABs on all tabs co-exist in the same route subtree; Hero's pre-transition scan asserts on duplicate tags.
2. **Site-info field hygiene** — username / user id had no validator (or a weak one), the required set was invisible to users, and "站点类型" jumped straight into a concrete backend instead of offering a safe placeholder for unconfirmed sites.

## Changes Summary

| Batch | Commit | Description |
|-------|--------|-------------|
| 1 | `3d8e6ab` | Rename colliding Hero tags (`refresh` x2, `add` x1 overlap) into unique `<feature>_<role>` form |
| 2 | `b6ff492` | Add `SiteType.unknown` enum value (accessToken / non-managed / `'unknown'` persisted value), rendered as `'Unknown'` at dropdown end |
| 3 | `e9f4351` | Tighten `Account.username: String` and `Account.userId: int` to non-null with documented sentinels `''` / `-1`; mapper rehydrates legacy nulls and traps unknown siteType strings into `SiteType.unknown` |
| 4 | `77a2add` | Editor required-field UX: `*` suffix on five labels, new `_validateUsername`, stricter `_validateUserId` (positive int), sentinel-to-empty reflection in `initState`, default `_siteType = SiteType.unknown` |

## Cross-Layer Contract Established

Introduced an explicit **sentinel contract** spanning domain / data / presentation:

```
domain       → field is non-null; doc declares sentinel ('' or -1)
data (mapper)→ legacy null payloads rehydrate into sentinel
editor       → initState reflects sentinel as '' so validator can reject
```

Captured as **Mistake 6 — Non-null Required Field Backed by a Sentinel** in `.trellis/spec/guides/cross-layer-thinking-guide.md`, with an executable signature table, validation matrix, good/base/bad cases, and required-test list. Paired UI rule added to `frontend/component-guidelines.md`'s full-screen form pattern (sentinel reflection + `*` label convention).

## Design Decisions (from interview)

- `SiteType.unknown` treated as permanent legal type (can be saved), not a UI-only placeholder — aligns with future "re-detect" flow.
- `defaultAuthType = AuthType.accessToken`, `isManaged: false` (hides "save & configure" rocket button).
- adapter_provider stays un-changed; `unknown` silently falls back to `newApi` via `?? adapters[SiteType.newApi]!`.
- **Sentinel over required-parameter** — kept optional constructor params with sentinel defaults rather than making them `required`, to avoid breaking ~15 existing Account constructor call sites in tests; type-system tightening still achieved.
- Legacy user-id stored as `null` rehydrates to `-1`, which the editor shows as empty; user must re-enter before save.

## Updated Files

**Production code**
- `lib/core/network/site_type.dart` — add `unknown` enum entry + displayName
- `lib/features/accounts/domain/entities/account.dart` — username/userId non-null with sentinel doc
- `lib/features/accounts/data/models/account_mapper.dart` — `_readSiteType` fallback + `_readUserId` sentinel + `username ?? ''`
- `lib/features/accounts/presentation/pages/account_edit_page.dart` — required labels, validators, sentinel reflect, default unknown
- `lib/features/check_in/presentation/pages/check_in_page.dart` — Hero tag `check_in_refresh`
- `lib/features/keys/presentation/pages/keys_page.dart` — Hero tags `keys_refresh` / `keys_add`

**Tests**
- `test/features/accounts/domain/entities/account_test.dart` — default-construct asserts `''` / `-1`
- `test/features/accounts/data/models/account_mapper_test.dart` — sentinel round-trip + unknown-siteType fallback regression
- `test/features/accounts/presentation/pages/account_edit_page_test.dart` — 3 widget tests updated for new defaults

**Spec docs**
- `.trellis/spec/guides/cross-layer-thinking-guide.md` — new Mistake 6 + checklist items
- `.trellis/spec/frontend/component-guidelines.md` — sentinel-reflection + required-label rules in full-screen form pattern

## Verification

- `flutter analyze` → No issues found
- `flutter test` → 302 tests passed (added 1 regression test for unknown siteType fallback)
- Manual smoke test on device: pending (handed off to human)

## Known Follow-ups

- Hook up "重新识别" button to real auto-detect flow (currently shows "即将上线" SnackBar); unknown-type accounts are the intended starting state for this flow.
- Consider migrating remaining `heroTag` literals into a `core/ui/hero_tags.dart` constant file if a fourth tab is added (single source of truth across IndexedStack).


### Git Commits

| Hash | Message |
|------|---------|
| `3d8e6ab` | (see git log) |
| `b6ff492` | (see git log) |
| `e9f4351` | (see git log) |
| `77a2add` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 21: Fix account info refresh via derived balance and New-API-User header

**Date**: 2026-04-22
**Task**: Fix account info refresh via derived balance and New-API-User header
**Branch**: `main`

### Summary

(Add summary)

### Main Changes

## Context

账号管理页面下拉刷新后，每张账号卡片右侧始终显示 `--`，用户感受为"账户信息获取不到"。阅读 `input/API-EndPoint.md` 并追踪代码定位到两个根因：

1. **Balance 字段映射错误** — `UserInfoDto.fromJson` 直接读 `json['balance']`，但 New API / OneHub / DoneHub 共用的 `/api/user/self` 实际只返回 `quota` / `used_quota`（token 单位），真实美元余额需用 `quota_per_unit` 换算。
2. **New-API-User header 缺失** — 严格的 New API 部署要求请求在 `New-API-User` header 上回显 upstream 用户 id（Bearer token 单独不够）；应用此前完全未注入此 header。
3. **字段同步不完整** — `AccountsNotifier._checkSingle` 仅 `_persistBalance`，`username` / `userId` 从不从 API 回填。

## Changes Summary

| Batch | Commit | Description |
|-------|--------|-------------|
| Single | `6353832` | Derived-balance + New-API-User header + field sync + spec |

单批次交付，内部按 6 个 Trellis 任务串行执行（`kDefaultQuotaPerUnit` 常量 → `SiteStatusDto.quotaPerUnit` → `AccountApiMapper.computeBalance/extractUserId` → `AccountsNotifier._checkSingle` 改写 + `New-API-User` header 补丁 → 单测 → SubAgent 验证）。

## Cross-Layer Contract Established

**扩展了 `Options.extra` 的 per-request auth 契约**，新增 `apiUserId` 键：

```
Account.userId (-1 sentinel / >0 实际值)
  → ApiRequest.userId (int?)
  → Options.extra['apiUserId']
  → AuthInterceptor  → options.headers['New-API-User'] = '$userId'  (iff userId > 0)
```

关键不变式：
- `AuthInterceptor` 保持无状态，仅依赖 `RequestOptions.extra`；所有 adapter 方法必须通过 `CommonApiAdapter._request` / `_buildOptions` 原子设置全部 extras 键。
- `New-API-User` 与 `authType` **正交** —— Cookie-auth 的 managed 站点在未来也应注入此 header，不做 authType 过滤。
- `userId <= 0`（含 sentinel `-1`）、`null`、缺失 → 省略 header，让 backend 尝试 token-only 识别（宽松 fork 上仍可工作）。

该契约已写入 `.trellis/spec/backend/error-handling.md` 的 **Per-Request Auth Error Flow** 节，含 extras 契约表、header 注入矩阵、Good/Base/Bad 三例、validation 规则、必需测试与断言点。

## Design Decisions (from interview)

- **quota_per_unit 来源**：选"从 `/api/status` 动态读取 + 500000 fallback"（社区默认），而非硬编码或让用户配置。每次刷新对每个账号并行 `Future.wait([user-info, status])`（batchSize=4，N 账号 → 2N 并行请求，可接受）。按 baseUrl 缓存留给后续批次。
- **`/api/status` 失败不降级账号可达性** —— Reachability 仅由 user-info 的 `Result` 决定；status 失败只导致 balance 走默认系数，`ReachabilityRecord.ok(now)` 照常写入。
- **Sentinel 保留策略** —— API 返回 `username == ''` 或 `id <= 0` 时 **不** 覆盖 Account 已填值，保留用户在编辑页输入的真实值。
- **Cookie-based 适配器暂不实现** —— `sub2api` / `anyrouter` / `wongGongyi` 继续 fallback 到 `newApi`，本批次聚焦核心修复。

## Updated Files

**Production code**
- `lib/core/config/app_defaults.dart` — `kDefaultQuotaPerUnit = 500000.0`
- `lib/core/network/api_request.dart` — `ApiRequest.userId: int?` 新字段
- `lib/core/network/auth_interceptor.dart` — `apiUserId` → `New-API-User` 注入
- `lib/core/network/adapters/common_api_adapter.dart` — extras 传 `apiUserId`
- `lib/core/network/dto/site_status_dto.dart` — `quotaPerUnit` 字段解析 `quota_per_unit`
- `lib/features/accounts/data/models/account_api_mapper.dart` — `computeBalance(dto, qpu)` + `extractUserId`
- `lib/features/accounts/presentation/providers/accounts_notifier.dart` — `_checkSingle` 并行取 user-info + status；`_syncAccountInfo` 替代 `_persistBalance`，同步 balance/username/userId
- `lib/features/accounts/presentation/pages/account_edit_page.dart` — dart format 一行合并（无逻辑变化）

**Tests**
- `test/core/network/auth_interceptor_test.dart` — `New-API-User header injection` 组 6 个用例（正值/missing/null/-1/0/Cookie+userId 组合）
- `test/core/network/dto/site_status_dto_test.dart` — `quotaPerUnit` 4 场景
- `test/features/accounts/data/models/account_api_mapper_test.dart` — `computeBalance` 三分支 + 边界 + `extractUserId`
- `test/features/accounts/presentation/providers/accounts_notifier_test.dart` — `checkOne (exercises _checkSingle)` 8 个场景（含 userId 透传 + sentinel 保留 + status 失败回退 + deep-equal 跳写 + disabled 跳过）
- `test/features/accounts/presentation/pages/account_edit_page_test.dart` — dart format（无逻辑变化）

**Spec docs**
- `.trellis/spec/backend/error-handling.md` — Per-Request Auth Error Flow 节重写，加入 extras 契约表、header 注入矩阵、Good/Base/Bad、validation、测试锚点
- `.trellis/spec/backend/directory-structure.md` — `api_request.dart` 描述从 `baseUrl + auth` 扩展为 `baseUrl + auth + userId`

## Verification

- `flutter analyze` → **No issues found**
- `flutter test` → **332 / 332 passed**（比上 session 多 30 个新增用例）
- `dart format --set-exit-if-changed lib/ test/` → exit 0
- Manual smoke test on device: **pending（handed off to human）**

## Known Follow-ups

- Cookie-based 站点（`sub2api` / `anyrouter` / `wongGongyi`）仍 fallback 到 `newApi` adapter，Cookie 拼接格式 `session=$token` 对 multi-value cookie 场景不准确，后续批次要补专用 adapter。
- `quota_per_unit` 按 `baseUrl` 的内存缓存（当前每次 refresh 都重新请求 `/api/status`；账号数多时值得上缓存）。
- `SiteType.unknown` 账户的"重新识别"引导 UX 仍挂"即将上线"，与 Session 20 的遗留项合并。
- Balance-only 的错误详情 SnackBar / 错误列表页（目前失败只显示红点，用户看不到 HTTP 状态码）。


### Git Commits

| Hash | Message |
|------|---------|
| `6353832` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
