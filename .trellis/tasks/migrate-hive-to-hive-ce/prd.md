# Hive → Hive CE Migration

## Background

Original `hive` / `hive_flutter` package is no longer actively maintained. Migrate to the community edition `hive_ce` / `hive_ce_flutter` (v2.19.3) for:
- Active maintenance and bug fixes
- Flutter Web WASM support
- DevTools Inspector extension
- Better performance

## Current Usage

- **Dependencies**: `hive_flutter: ^1.1.0` (pulls in `hive` transitively)
- **No TypeAdapters / @HiveType / @HiveField**: All data is stored as Map<String, dynamic>
- **No HiveObject / HiveList**: Pure key-value + map serialization
- **No hive_generator**: No build_runner codegen for Hive

### Files importing hive (15 files)

1. `lib/main.dart` — `import 'package:hive_flutter/hive_flutter.dart'`
2. `lib/core/storage/hive_store.dart` — `import 'package:hive_flutter/hive_flutter.dart'`
3. `lib/features/settings/data/datasources/theme_local_datasource.dart`
4. `lib/features/settings/data/datasources/global_proxy_local_datasource.dart`
5. `lib/features/settings/data/datasources/browser_local_datasource.dart`
6. `lib/features/tags/data/datasources/tags_local_datasource.dart`
7. `lib/features/accounts/data/datasources/account_reachability_local_datasource.dart`
8. `lib/features/accounts/data/datasources/accounts_local_datasource.dart`
9. `lib/features/keys/data/datasources/keys_local_datasource.dart`
10. `lib/features/check_in/data/datasources/check_in_request_log_local_datasource.dart`
11. `lib/features/check_in/data/datasources/scheduler_config_local_datasource.dart`
12. `lib/features/check_in/data/datasources/check_in_local_datasource.dart`
13. `lib/features/backup/data/datasources/backup_hive_reader.dart`
14. `lib/features/backup/data/datasources/backup_password_store.dart`
15. `lib/features/backup/presentation/providers/backup_providers.dart`

### Hive API used (all compatible with hive_ce)

- `Hive.initFlutter()` — initialization
- `Hive.openBox(name)` — open 10 boxes
- `Hive.box(name)` — get singleton box instance
- `Box.get()`, `Box.put()`, `Box.delete()`, `Box.containsKey()`, `Box.clear()`, `Box.keys`, `Box.values`

### 10 Hive boxes

`app_data`, `accounts`, `keys`, `tags`, `check_in_tasks`, `check_in_results`, `check_in_request_logs`, `scheduler_config`, `account_reachability`, `network_proxy`

## Migration Plan

Since this project uses ONLY basic Hive API (no TypeAdapters, no codegen, no HiveObject), the migration is a straightforward package swap:

### Step 1: Update pubspec.yaml

- Remove: `hive_flutter: ^1.1.0`
- Add: `hive_ce_flutter: ^2.19.3`

### Step 2: Replace all imports (15 files)

- `package:hive_flutter/hive_flutter.dart` → `package:hive_ce_flutter/hive_flutter.dart`

### Step 3: Run flutter pub get

- Verify dependency resolution

### Step 4: Verify

- `flutter analyze` — zero warnings
- `dart format .` — formatting
- `flutter test` — all tests pass
- Manual smoke test: app launches, data persists

## Risk Assessment

- **Low risk**: No TypeAdapters, no codegen, no HiveObject
- **Data compatibility**: hive_ce is a drop-in replacement; existing box files remain compatible
- **API compatibility**: All used APIs are identical between hive and hive_ce
- **Rollback**: Simple — revert pubspec.yaml + imports

## Acceptance Criteria

- [ ] `hive_flutter` removed from pubspec.yaml
- [ ] `hive_ce_flutter: ^2.19.3` added to pubspec.yaml
- [ ] All 15 files updated with new import
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` — 0 warnings
- [ ] `dart format .` applied
- [ ] `flutter test` passes
- [ ] App launches successfully and data persists
