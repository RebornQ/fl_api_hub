# Database Guidelines

> Local persistence patterns and conventions for this project.

---

## Overview

This project uses **Hive CE** (Community Edition) as the local key-value database. Hive is a lightweight, fast, NoSQL database written in pure Dart.

**Package**: `hive_ce_flutter: ^2.3.4` (migrated from `hive_flutter: ^1.1.0`)

**Why Hive CE?**
- Actively maintained fork of the original Hive package
- Flutter Web WASM support
- DevTools Inspector extension
- Better performance and smaller file sizes

---

## Architecture

### Storage Abstraction

The project defines a `KeyValueStore` interface with a Hive-backed implementation:

```dart
/// Interface for a generic key-value store.
abstract class KeyValueStore {
  Future<T?> read<T>(String key);
  Future<void> write<T>(String key, T value);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}

/// [KeyValueStore] implementation backed by a Hive [Box].
class HiveStoreImpl implements KeyValueStore {
  final Box _box;
  HiveStoreImpl(this._box);
  // ...
}
```

**Location**: `lib/core/storage/hive_store.dart`

### Data Serialization Pattern

Structured data (accounts, API keys, preferences) is stored in Hive boxes as **plaintext maps** (`Map<String, dynamic>`), NOT as typed Hive objects.

**Why this pattern?**
- No `@HiveType` / `@HiveField` annotations needed
- No `hive_generator` / `build_runner` codegen
- Simpler entity-to-map serialization via mapper classes
- Forward compatibility with schema changes

**Example**:
```dart
// Entity → Map serialization in data source
Future<void> saveAccount(Account account) async {
  await _box.put(account.id, AccountMapper.toMap(account));
}

// Map → Entity deserialization
Account? getAccount(String id) {
  final raw = _box.get(id);
  return raw != null ? AccountMapper.fromMap(Map<String, dynamic>.from(raw)) : null;
}
```

---

## Hive Boxes

### Box Registry

All boxes are opened at app startup in `initHive()`:

| Box Name | Purpose | Entity Type |
|----------|---------|-------------|
| `app_data` | General preferences, simple key-value data | Various |
| `accounts` | Account entity storage | Account |
| `keys` | API key entity storage | ApiKey |
| `tags` | Tag entity storage (cross-feature labels) | Tag |
| `check_in_tasks` | Check-in task entity storage | CheckInTask |
| `check_in_results` | Check-in result entity storage | CheckInResult |
| `check_in_request_logs` | Persistent request logs for check-in | RequestLog |
| `scheduler_config` | Auto-check-in scheduler config | SchedulerConfig |
| `account_reachability` | Cached website reachability per account | Reachability |
| `network_proxy` | Global network proxy setting | GlobalProxySetting |

### Initialization

```dart
Future<void> initHive() async {
  if (kIsWeb) {
    await Hive.initFlutter();
  } else if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await Hive.initFlutter('.fl-api-hub/hive');
  } else {
    await Hive.initFlutter('hive');
  }
  await Future.wait([
    Hive.openBox('app_data'),
    Hive.openBox('accounts'),
    // ... all other boxes
  ]);
}
```

**Call location**: `lib/main.dart`, before `runApp()`

### Accessing Boxes

Use `Hive.box(name)` to get a singleton instance of an already-opened box:

```dart
final box = Hive.box('accounts');
await box.put(id, data);
final data = box.get(id);
```

**Note**: `Hive.box()` throws if the box hasn't been opened yet. Always ensure `initHive()` completes before accessing boxes.

---

## Riverpod Integration

The `KeyValueStore` is exposed via Riverpod provider:

```dart
/// Riverpod provider for the application-wide [KeyValueStore].
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return HiveStoreImpl(Hive.box('app_data'));
});
```

Feature-specific data sources receive boxes via constructor injection:

```dart
final accountsLocalDataSourceProvider = Provider<AccountsLocalDataSource>((ref) {
  return AccountsLocalDataSource(Hive.box(_boxName));
});
```

---

## Migration: Hive → Hive CE

### Why Migrate?

The original `hive` / `hive_flutter` packages are no longer actively maintained. Hive CE is the community-maintained fork that provides:
- Active maintenance and bug fixes
- Flutter Web WASM compilation support
- DevTools Inspector extension
- Extended type ID range (65439 vs 223)
- Built-in `Duration` adapter and `Set` support

### Migration Steps (for this project)

Since this project uses **no TypeAdapters, no `@HiveType`/`@HiveField` annotations, no `HiveObject`, and no `hive_generator`**, the migration is a straightforward package swap:

1. **Update `pubspec.yaml`**:
   ```yaml
   # Remove:
   # hive_flutter: ^1.1.0
   
   # Add:
   dependencies:
     hive_ce_flutter: ^2.3.4
   ```

2. **Replace all imports** (17 files):
   ```dart
   // Before:
   import 'package:hive_flutter/hive_flutter.dart';
   
   // After:
   import 'package:hive_ce_flutter/hive_flutter.dart';
   ```

3. **Run verification**:
   ```bash
   flutter pub get
   flutter analyze
   dart format .
   flutter test
   ```

### API Compatibility

All Hive APIs used in this project are compatible with Hive CE:
- `Hive.initFlutter()`
- `Hive.openBox(name)`
- `Hive.box(name)`
- `Box.get()`, `Box.put()`, `Box.delete()`, `Box.containsKey()`, `Box.clear()`, `Box.keys`, `Box.values`

**No code changes required** beyond the import path.

### Data Compatibility

Existing Hive box files are fully compatible with Hive CE. No data migration needed.

---

## Common Mistakes

### Mistake: Using `Hive.box()` before `initHive()` completes

**Symptom**: `HiveError: Box has not been opened.`

**Fix**: Ensure `initHive()` is awaited before any box access:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();  // Must complete first
  // Now safe to use Hive.box()
  runApp(const App());
}
```

### Mistake: Storing entities directly instead of maps

**Symptom**: Type errors, serialization issues, schema brittleness.

**Fix**: Always serialize to `Map<String, dynamic>` via mapper classes:
```dart
// Don't:
await box.put(id, account);

// Do:
await box.put(id, AccountMapper.toMap(account));
```

### Mistake: Forgetting to handle null values

**Symptom**: `Null check operator used on a null value`

**Fix**: Always handle the null case when reading:
```dart
final raw = box.get(id);
if (raw == null) return null;
return AccountMapper.fromMap(Map<String, dynamic>.from(raw));
```

### Mistake: Using TextEditingController after dispose

**Symptom**: `A TextEditingController was used after being disposed`

**Cause**: Calling methods on a controller after `dispose()` has been called.

**Fix**: Ensure dispose order is correct — remove overlays first, then dispose controllers:
```dart
@override
void dispose() {
  // Remove overlay BEFORE disposing controller
  _overlayEntry?.remove();
  _overlayEntry = null;
  // Now safe to dispose
  _searchController.dispose();
  super.dispose();
}
```

---

## Naming Conventions

- **Box names**: `snake_case` (e.g., `app_data`, `check_in_tasks`)
- **Keys in boxes**: Entity `id` (String) for structured data, descriptive names for preferences
- **Mapper classes**: `{Entity}Mapper` with `toMap()` and `fromMap()` static methods

---

## Testing

### Unit Tests

Data sources can be tested with in-memory Hive boxes:

```dart
setUp(() async {
  await Hive.initFlutter();
  await Hive.openBox('test_accounts');
  dataSource = AccountsLocalDataSource(Hive.box('test_accounts'));
});

tearDown(() async {
  await Hive.deleteBox('test_accounts');
});
```

### Widget Tests

For widget tests that need Hive, ensure `initHive()` is called in the test setup or use a mock `KeyValueStore`.

---

## References

- [Hive CE Documentation](https://docs.hive.isar.community/#/)
- [Hive CE on pub.dev](https://pub.dev/packages/hive_ce)
- [Migration Guide](https://pub.dev/packages/hive_ce/changelog)
