# State Management

> How state is managed in this project.

---

## Overview

This project uses **Riverpod** for state management:

- **Providers**: Global state is exposed via Riverpod providers (`Provider`, `StateProvider`, `NotifierProvider`, `AsyncNotifierProvider`).
- **AsyncNotifier**: For loading/mutating async data (accounts, keys, tags, etc.).
- **Hive**: Local persistence layer; providers hydrate from Hive boxes on `build()`.
- **Patterns**: See "Reusable Patterns" sections for established conventions.

---

## State Categories

### Local UI State

Use local widget state for ephemeral interaction state that belongs to a single screen/widget.

Examples:

- Form field controllers (`TextEditingController`)
- Animation state
- Temporary selection state before commit

### Global App State

Implemented via Riverpod providers:

- `accountsProvider` — list of accounts
- `tagsProvider` — list of tags
- `groupsProvider` — key groups
- `globalProxyProvider` — global proxy settings

### Server State

Network layer is implemented:

- `DioClient` in `lib/core/network/` handles HTTP requests
- Repositories in `lib/features/<feature>/data/repositories/` wrap API calls
- Results are returned as `Result<T>` (Success/Failure sealed class)
- Providers hydrate from Hive and sync with remote APIs

---

## When to Use Global State

Current rule for this repository:

- Use Riverpod providers for state that is shared across widgets/features.
- Use `AsyncNotifier` for async data loading with built-in loading/error states.
- Promote state out of a widget when:
  - Multiple screens need the same data
  - State must survive navigation boundaries
  - State represents business logic, not UI-only concerns

---

## Server State

Server-state approach:

- `DioClient` provides HTTP client with proxy support (see Pattern 8)
- Repositories wrap API calls and return `Result<T>`
- Providers hydrate from Hive on startup and sync with remote
- Background updates use Pattern 3 (Progressive State Update)

---

## Common Mistakes

- Escalating simple local UI state into app-wide state too early.
- Claiming Riverpod is already used when `pubspec.yaml` does not include it.
- Mixing domain/data concerns into `StatefulWidget` classes.
- Treating temporary bootstrap demo code as a permanent architecture pattern.

---

## Reusable Patterns (from accounts reachability, 2026-04)

These three patterns emerged from wiring per-account website reachability into
the accounts page. They are project conventions — reuse them when building
similar features (e.g. keys status, site version polling, balance dashboards).

### Pattern 1 — Hive-Hydrated Map Notifier

**When to use**: you need an in-memory `Map<Id, Record>` that persists across
restarts but is mutated from the UI layer. The domain entity should stay
unpolluted.

**Structure**:

```
domain/repositories/<thing>_repository.dart   // interface (no Result wrapper
                                              //   — missing values are normal)
data/datasources/<thing>_local_datasource.dart  // Hive box read/write
data/repositories/<thing>_repository_impl.dart  // passes through
presentation/providers/<thing>_providers.dart   // Notifier hydrates in build()
```

**Reference implementation**:

- `lib/features/accounts/presentation/providers/account_reachability_providers.dart` — `ReachabilityMapNotifier`
- `lib/features/accounts/data/datasources/account_reachability_local_datasource.dart`

**Signature contract**:

```dart
class XMapNotifier extends Notifier<Map<String, XRecord>> {
  @override
  Map<String, XRecord> build() =>
      ref.read(xRepositoryProvider).getAll();            // sync hydrate

  Future<void> put(String id, XRecord record) async {
    await ref.read(xRepositoryProvider).put(id, record); // write-through
    state = {...state, id: record};                       // new map ref
  }

  Future<void> remove(String id) async {
    await ref.read(xRepositoryProvider).remove(id);
    if (!state.containsKey(id)) return;
    final next = Map<String, XRecord>.from(state)..remove(id);
    state = next;
  }
}
```

**Record serialization contract** (for `ReachabilityRecord`):

```dart
class ReachabilityRecord {
  final ReachabilityStatus status;
  final DateTime checkedAt;
  final FailCategory? failCategory;
  final bool? checkInStatusToday;  // API-derived check-in status

  // Serialization must handle nullable fields:
  Map<String, dynamic> toMap() => {
    'status': status.name,
    'checkedAt': checkedAt.toIso8601String(),
    'failCategory': failCategory?.name,
    'checkInStatusToday': checkInStatusToday,  // bool? → null-safe
  };

  static ReachabilityRecord? fromMap(Map<String, dynamic> map) {
    // ... parse status and checkedAt ...
    return ReachabilityRecord(
      status: status,
      checkedAt: checkedAt,
      failCategory: failCategory,
      checkInStatusToday: map['checkInStatusToday'] as bool?,  // null if missing
    );
  }
}
```

**Rules**:
- Repository returns raw `Map` / `void` — **not** `Result<T>`. Missing or
  malformed records are normal, not errors.
- When adding new fields to the record, **always** handle `null` in `fromMap`
  for backward compatibility with existing cached data.
- Always produce a new map reference (`{...state, ...}`) — in-place mutation
  breaks Riverpod equality checks.
- Hive box must be opened in `lib/core/storage/hive_store.dart#initHive()`
  before the app is constructed.
- Consumers watch via `.select()` to rebuild only on their own key:
  `ref.watch(xMapProvider.select((m) => m[myId]))`.

**Don't**:
- Don't store the status on the domain entity — that forces a Hive migration
  every time the UI needs a new UX-only field.
- Don't wrap reads in `Result` or `AsyncValue` — hydration is synchronous
  after `initHive()`.

### Pattern 2 — Batched Concurrent Scan with Throttle

**When to use**: a user-triggered or page-entry scan that fans out one
request per item across N items, where N may be 1 or 50. Must not flood the
device, must not re-run on every rapid tab switch.

**Reference implementation**:

- `lib/features/accounts/presentation/providers/accounts_notifier.dart` —
  `AccountsNotifier.checkAll({bool force})`, `_runBatched`
- `lib/features/accounts/presentation/providers/account_reachability_providers.dart` — `reachabilityThrottleProvider`, `checkingIdsProvider`

**Signature contract**:

```dart
const _batchSize = 4;                              // tune per workload
const _throttleWindow = Duration(seconds: 30);

Future<void> checkAll({bool force = false}) async {
  final lastAt = ref.read(throttleProvider);
  if (!force &&
      lastAt != null &&
      DateTime.now().difference(lastAt) < _throttleWindow) {
    return;                                         // swallow repeat scans
  }

  final items = await future;                       // await notifier load
  final targets = items.where(_eligible).toList();

  final checking = ref.read(checkingIdsProvider.notifier);
  checking.markChecking(targets.map((t) => t.id));
  try {
    await _runBatched(targets, _batchSize, _one);
  } finally {
    checking.clear();                                // drain on any exit path
    ref.read(throttleProvider.notifier).stamp();
  }
}

Future<void> _runBatched<T>(
  List<T> items, int size, Future<void> Function(T) task,
) async {
  for (var i = 0; i < items.length; i += size) {
    final chunk = items.skip(i).take(size).toList();
    await Future.wait(chunk.map(task));              // one chunk at a time
  }
}
```

**Rules**:
- Expose a `force: bool` flag — pull-to-refresh and explicit user intent
  always bypass throttle.
- Ineligible items (disabled, missing credentials) must be filtered **and**
  have their cached status cleared in the same pass.
- `checkingIds` must always be drained in `finally` — never leave the UI
  stuck in a loading pulse if a batch throws.
- Stamp the throttle timestamp **after** the scan, not before — if a scan
  aborts early (empty list), still stamp so we don't re-enter on the next
  frame.
- Batch size defaults to **4** unless profiling says otherwise. Tuning up
  harms low-end devices on mobile networks.

**Pair with Pattern 1**: the per-item task typically writes to a Hive-hydrated
map notifier and, optionally, patches the primary entity via Pattern 3.

### Pattern 2.1 — Multi-API Parallel Fetch in Batched Scan

> **Trigger**: extends Pattern 2 when each item requires multiple API calls.
> Apply when a single scan needs to fetch data from 2+ endpoints per item.

**Scope / Trigger**

- Trigger: `_checkSingle` needs to fetch account info, site status, AND
  check-in status in one pass. Parallel execution minimizes latency.
- Mandatory when the per-item task can be decomposed into independent API calls.

**Signatures**

```dart
// lib/features/accounts/presentation/providers/accounts_notifier.dart
Future<void> _checkSingle(Account account) async {
  // ...

  // Compute current month for check-in status API.
  final now = DateTime.now();
  final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final results = await Future.wait([
    remote.fetchAccountInfo(request),
    remote.fetchSiteStatus(request),
    checkInRemote.fetchCheckInStatus(request, month: currentMonth),
  ]);
  final userInfoResult = results[0] as Result<UserInfoDto>;
  final statusResult = results[1] as Result<SiteStatusDto>;
  final checkInStatusResult = results[2] as Result<CheckInStatusDto>;

  // Process results...
}
```

**Contracts**

| API Call | Purpose | Failure Behavior |
|----------|---------|------------------|
| `fetchAccountInfo` | User info, balance, userId | Marks account as unreachable |
| `fetchSiteStatus` | Site version, quotaPerUnit | Degrades to default quota factor |
| `fetchCheckInStatus` | Today's check-in status | Sets `checkInStatusToday = null` |

**Validation & Error Matrix**

| Condition | Result |
|-----------|--------|
| All 3 APIs succeed | `ReachabilityRecord.ok(timestamp, checkInStatusToday: dto.checkedInToday)` |
| `fetchAccountInfo` fails | `ReachabilityRecord.fail(timestamp, category)`; other results ignored |
| `fetchSiteStatus` fails | Uses `kDefaultQuotaPerUnit`; still marks OK |
| `fetchCheckInStatus` fails | `checkInStatusToday = null`; still marks OK |
| Any throws | Catches and marks as `ReachabilityRecord.fail` |

**Good / Base / Bad Cases**

- **Good**: Three parallel API calls complete in ~1 RTT. UI shows fresh
  balance + check-in status.
- **Base**: Check-in API fails or returns malformed data. `checkInStatusToday`
  is `null`, account still marked OK.
- **Bad**: Sequential awaits (`await fetchAccountInfo(); await fetchSiteStatus()`)
  triples latency.

**Tests Required**

- `accounts_notifier_test.dart` — `_checkSingle`:
  - All 3 APIs succeed → `checkInStatusToday` matches DTO value.
  - `fetchCheckInStatus` fails → `checkInStatusToday` is `null`, account still OK.
  - `fetchAccountInfo` fails → reachability is `fail`, other results ignored.
  - Month string format is `YYYY-MM` with zero-padded month.

**Wrong vs Correct**

```dart
// Wrong — sequential awaits triple latency.
final userInfo = await remote.fetchAccountInfo(request);
final status = await remote.fetchSiteStatus(request);
final checkIn = await checkInRemote.fetchCheckInStatus(request, month: month);
```

```dart
// Correct — parallel execution.
final results = await Future.wait([
  remote.fetchAccountInfo(request),
  remote.fetchSiteStatus(request),
  checkInRemote.fetchCheckInStatus(request, month: month),
]);
```

**Design Decision — API as Single Source of Truth for Check-In Status**

When displaying check-in status in the account list, the API `checkedInToday`
field is the **single source of truth**. Local check-in results are NOT used
for icon display. This ensures:

1. Consistency with what the server sees (user may have checked in on web).
2. Simpler logic — no need to reconcile local vs API state.
3. Fresh data on every refresh — no stale local records.

```dart
// account_card.dart — API status is authoritative.
({IconData icon, Color color})? _resolveCheckInIcon({
  required bool autoCheckInEnabled,
  required bool? apiCheckInStatusToday,
}) {
  if (!autoCheckInEnabled) return null;

  // API status is the single source of truth.
  if (apiCheckInStatusToday == true) {
    return (icon: Icons.check_circle, color: const Color(0xFF10B981));
  }

  return (icon: Icons.cancel, color: const Color(0xFFEF4444));
}
```

### Pattern 3 — Progressive State Update (no `AsyncLoading`)

**When to use**: you are inside an `AsyncNotifier<List<T>>` and need to
patch one element as a background result arrives, without blanking the whole
list to a spinner and without touching fields the user hasn't asked to
change (like `updatedAt`).

**Reference implementation**:

- `lib/features/accounts/presentation/providers/accounts_notifier.dart` —
  `_persistBalance`

**Signature contract**:

```dart
Future<void> _persistPartial(T entity, FieldPatch patch) async {
  final patched = entity.copyWith(/* only the field(s) from patch */);
  // DO NOT touch updatedAt / createdAt / any unrelated field.

  final result = await repo.update(patched);
  if (result is Failure) return;                     // silent — background op

  final current = state.valueOrNull;
  if (current == null) return;
  state = AsyncData([
    for (final e in current) e.id == patched.id ? patched : e,
  ]);                                                // in-place swap, same
                                                     //   list length & order
}
```

**Rules**:
- **Never** set `state = const AsyncLoading()` in a background patch path —
  it blanks the UI and disrupts users mid-interaction. `AsyncLoading` is
  reserved for user-initiated operations where blocking the UI is the right
  answer (create/update/delete forms).
- **Never** bump `updatedAt` for data that came from the server (balance,
  status, counts). `updatedAt` means "user edited this" and sorting /
  filtering may depend on it.
- Failures on partial patches are logged/swallowed, not surfaced as
  `AsyncError` — the user did not request this update.
- Preserve list order: rebuild via `[for (final e in current) ...]`, never
  `.map(...)` into a new list with a different comparator.

**Do not use this pattern** for operations the user explicitly triggered
(save button, delete confirm) — those should use the normal
`AsyncLoading → AsyncData / AsyncError` flow so errors propagate to the
form.

---

## Cross-Pattern Flow

A typical "fan-out background refresh" feature composes all three:

```
 page.initState()
   └─ postFrameCallback
        └─ notifier.checkAll()                         [Pattern 2]
             ├─ markChecking(ids)    → UI starts breathing dots
             ├─ _runBatched(4)
             │    └─ for each item:
             │         ├─ Future.wait([                [Pattern 2.1]
             │         │    fetchAccountInfo(),
             │         │    fetchSiteStatus(),
             │         │    fetchCheckInStatus(month),
             │         │  ])
             │         ├─ hydratedMap.put(id, record)  [Pattern 1]
             │         └─ _persistPartial(entity, dto) [Pattern 3]
             └─ finally: markDone() + stamp throttle
```

**Required tests for this composition**:
- Unit: classify function (error → category) covers 4xx / 5xx / timeout /
  unknown.
- Widget/Notifier: disabled items skip + clear cache; `force: true` bypasses
  throttle; `markChecking` drained on thrown task.
- Regression: `updatedAt` **not** touched by the partial patch path.

---

## Reusable Patterns (from tags + account edit, 2026-04)

These two patterns were added during the account-edit dialog rewrite and
the new tags feature. They sit at the `presentation` ↔ `data` boundary and
encode concurrency + cross-feature integrity invariants that are easy to
forget when adding a new feature.

### Pattern 4 — Serialized Writes in an AsyncNotifier

**When to use**: an `AsyncNotifier` exposes mutation methods that can be
called back-to-back by the same UI action (tag picker "create" button,
quick double-tap on save, form field auto-save). Without serialization,
two concurrent calls may both observe pre-write state and each insert a
"new" record, producing duplicates.

**Reference implementation**:

- `lib/features/tags/presentation/providers/tags_notifier.dart` —
  `TagsNotifier._enqueue`, `upsertByName`, `rename`, `delete`

**Signature contract**:

```dart
class XNotifier extends AsyncNotifier<List<X>> {
  // Chain of pending write operations. Each write awaits the previous
  // one to settle (success *or* failure) before running its own work.
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<List<X>> build() async {
    ref.keepAlive();                         // stay resident across
                                             //   short-lived UIs
    final r = await ref.read(xRepoProvider).getAll();
    return r.when(
      onSuccess: (list) => list,
      onFailure: (e) => throw e,
    );
  }

  Future<X> upsertByName(String name) {
    return _enqueue(() async {
      final r = await ref.read(xRepoProvider).upsertByName(name);
      return switch (r) {
        Success(:final data) => () { _mergeInState(data); return data; }(),
        Failure(:final exception) => throw exception,
      };
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() action) async {
    final previous = _writeQueue;
    final completer = Completer<void>();
    _writeQueue = completer.future;
    try {
      // Swallow the previous error so it does not cascade into ours.
      await previous.catchError((Object _, StackTrace _) {});
      return await action();
    } finally {
      completer.complete();
    }
  }
}
```

**Rules**:
- Every state-mutating public method goes through `_enqueue`. Reads
  (`build`, derived getters) do NOT enqueue.
- `previous.catchError(...)` must swallow the prior failure so a bad
  earlier write does not poison subsequent writes with an unrelated
  `AsyncError`.
- `_mergeInState` edits the local list via a new `AsyncData([...next])`
  — never mutates the existing list in-place.
- `ref.keepAlive()` is only appropriate when the dataset is small and
  universally useful (tag list, short preference sets). Large feeds
  should rely on implicit invalidation instead.

**Don't**:
- Don't add per-method locks or `synchronized` packages — the single
  `_writeQueue` field is sufficient and survives `dispose()` because
  `AsyncNotifier` instances are rebuilt fresh on next listen.
- Don't rely on Riverpod's `AsyncLoading` alone to serialize — back-to-back
  public method calls execute between microtasks and neither sees the
  other's `AsyncLoading` before acting.

**Required tests**:
- Concurrent same-value test: fire `upsertByName('Prod')` and
  `upsertByName('prod')` in `Future.wait` — both must return the same id
  (`counter == 1` on the underlying creation path).
- Failure isolation: a failing `upsertByName` must not leave the next
  write pending; assert the next `upsertByName` resolves normally.
- State consistency: after N serialized writes the state list length
  equals the unique normalized keys.

### Pattern 5 — Cross-Feature Cascade Delete via Sibling Repository

> **Trigger**: new cross-layer contract. Apply the full 7-section
> treatment whenever one feature's deletion must update another
> feature's data.

**Scope / Trigger**

- Trigger: deleting an entity in feature `A` would leave dangling
  references inside feature `B`'s records.
- Mandatory when referenced ids persist to local storage / backups /
  WebDAV and lazy "filter on read" would silently hide the issue.

**Signatures**

```dart
// Sibling contract, owned by the feature that holds the back-reference.
abstract class BsRepository {
  /// Returns the number of B records whose reference list was modified.
  Future<Result<int>> removeAReferenceFromAllBs(String aId);
}

// Deleting feature A drives the cascade.
abstract class AsRepository {
  Future<Result<void>> delete(String aId);
}
```

Reference implementation (tags → accounts):

- `lib/features/accounts/domain/repositories/accounts_repository.dart` —
  `removeTagFromAllAccounts(String tagId) -> Future<Result<int>>`
- `lib/features/accounts/data/repositories/accounts_repository_impl.dart`
- `lib/features/tags/data/repositories/tags_repository_impl.dart` —
  `TagsRepositoryImpl.delete` (cascade orchestration)
- `lib/features/tags/presentation/providers/tags_notifier.dart` —
  `TagsNotifier.delete` (UI-level cache invalidation)

**Contracts**

| Step | Side | Input | Output | Constraint |
|------|------|-------|--------|-----------|
| 1    | A    | `aId` | existence check | Fail fast with `StorageException('A not found')` if missing |
| 2    | B    | `aId` | `Result<int>` count | Must not throw; exceptions become `Failure(StorageException)` |
| 3    | A    | `aId` | void | Only delete after step 2 Success |
| 4    | UI   | —     | —      | `ref.invalidate(bProvider)` so consumers re-read |

Required env / wiring: both repositories and their providers must be
reachable from a single Riverpod graph so the deleting notifier can
`ref.read(bRepositoryProvider)`.

**Validation & Error Matrix**

| Condition                              | Result                                              |
|----------------------------------------|-----------------------------------------------------|
| A does not exist                       | `Failure(StorageException('A not found'))`; no B write |
| B cascade returns `Failure`            | Abort delete; A record stays on disk; surface B error |
| B cascade returns `Success(n)`         | Proceed to delete A                                 |
| A delete throws                        | `Failure(StorageException)`; orphan state possible — callers must re-run delete |
| No B referenced A                      | `Success(0)` from cascade; A delete proceeds        |

**Good / Base / Bad Cases**

- **Good**: Cascade is atomic from the user's perspective — either both A
  and B update, or nothing visible changes (error toast surfaces).
- **Base**: Cascade runs even if zero B references exist — negligible
  cost, keeps the control flow uniform.
- **Bad**: Lazy filter on read ("skip tagIds that no longer resolve").
  Masks the bug, breaks WebDAV backups, causes duplicate tags when the
  user restores a backup then recreates the same-named tag.

**Tests Required**

- `a_repository_impl_test.dart` — `removeAReferenceFromAllBs`:
  - Updates only Bs that reference `aId`, returns exact count.
  - Leaves other `aIds` in the same B record intact.
  - Returns `Failure` on underlying storage errors.
- `b_repository_impl_test.dart` — `delete`:
  - Calls sibling cascade **before** deleting the A record.
  - Aborts and leaves A on disk if cascade fails.
  - Fails fast if A does not exist (sibling is not called).
- `b_notifier_test.dart` — `delete`:
  - After success, the A list state drops the id AND `ref.invalidate`
    causes `bProvider` to re-read so downstream UI sees the cleaned
    back-references.

**Wrong vs Correct**

```dart
// Wrong — reads tagIds through a lazy filter, leaves orphans on disk.
List<Tag> selectedTags(Account a, List<Tag> all) {
  final byId = {for (final t in all) t.id: t};
  return a.tagIds
      .map((id) => byId[id])
      .whereType<Tag>()
      .toList();                            // orphan ids silently dropped
}
```

```dart
// Correct — delete flow is the single place that cleans up references.
Future<Result<void>> delete(String tagId) async {
  final cascade = await _accounts.removeTagFromAllAccounts(tagId);
  if (cascade is Failure<int>) return Failure<void>(cascade.exception);
  await _local.delete(tagId);
  return const Success(null);
}
```

### Pattern 6 — Enabled-First Stable Partition Sort

**When to use**: displaying a list of accounts (or any entity with
`enabled` + `sortOrder` fields) where enabled items appear above
disabled items, preserving user-defined order within each group.

**Reference implementations**:

- `lib/features/accounts/presentation/providers/accounts_filter_providers.dart`
  — `filteredAccountsProvider` (L124-128)
- `lib/features/keys/presentation/pages/keys_page.dart` —
  `_sortAccounts` helper (L453-460)

**Signature contract**:

```dart
List<Account> sortAccounts(List<Account> accounts) {
  final enabled = accounts.where((a) => a.enabled).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final disabled = accounts.where((a) => !a.enabled).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [...enabled, ...disabled];
}
```

**Rules**:
- Use stable O(n) partition (`where` + spread), not `List.sort` with a
  comparator that checks `enabled`. This guarantees deterministic order
  even when `sortOrder` values collide.
- Within each partition, sort by `sortOrder` ASC (lower = earlier).
- When this pattern appears in ≥2 places in the same feature area,
  consider extracting to a shared utility. For now, the two usages are
  in separate features (accounts filter vs keys page), so inline is fine.

**Don't**:
- Don't use a single `list.sort((a, b) { final cmp = a.enabled ? 0 : 1;
  ... })` — `List.sort` is not guaranteed stable in Dart, so equal-rank
  items may shuffle on each sort call.

### Pattern 7 — Cross-Feature Lookup Map for Search

**When to use**: a derived provider needs to match against names or
labels from another feature's data (e.g. searching accounts by tag name),
and the cross-feature data is small enough to fit in memory.

**Reference implementation**:

- `lib/features/accounts/presentation/providers/accounts_filter_providers.dart`
  — `filteredAccountsProvider` watches `tagsProvider` to build a
  `tagIdToName` lookup for tag-based search.

**Signature contract**:

```dart
final derivedProvider = Provider<AsyncValue<View>>((ref) {
  final mainAsync = ref.watch(mainProvider);
  final crossAsync = ref.watch(crossFeatureProvider);

  // Build lookup map from cross-feature data.
  final lookupMap = <String, String>{};
  crossAsync.whenData((items) {
    for (final item in items) {
      lookupMap[item.id] = item.name.toLowerCase();
    }
  });

  return mainAsync.whenData((list) {
    // Use lookupMap in search/filter logic.
    // When crossAsync is loading/error, lookupMap is empty →
    // cross-feature matching silently skips (safe degradation).
  });
});
```

**Rules**:
- Use `whenData` (not `valueOrNull` or `!`) to build the lookup — this
  gracefully handles loading and error states by leaving the map empty.
- Lowercase both the query and the map values to ensure case-insensitive
  matching.
- The lookup map is built inside the provider body, not cached across
  rebuilds — Riverpod already memoises the provider output, so redundant
  map construction is avoided automatically.
- Only suitable when the cross-feature dataset is bounded (tags, groups,
  settings). Large datasets should use indexed data sources instead.

**Don't**:
- Don't `await` the cross-feature provider inside a synchronous
  `Provider`. Use `whenData` for non-blocking access.
- Don't duplicate the lookup logic in multiple providers — if a second
  consumer needs the same map, extract it to a dedicated `Provider<Map>`.

**Don't**:
- Don't call the sibling cascade *after* deleting the primary record.
  An intermittent failure on step 2 leaves B with references to a
  non-existent A.
- Don't substitute `on catch` + retry on the UI side — fix the flow at
  the repository layer so every caller gets the same guarantee.

---

## Reusable Patterns (from proxy config, 2026-04)

These patterns emerged from implementing per-account and global proxy
configuration with a Dio instance pool. They encode the contract between
proxy resolution, Dio instance caching, and cross-layer proxy propagation.

### Pattern 8 — Dio Instance Pool Keyed by ProxyConfig

> **Trigger**: new cross-layer contract. Apply the full 7-section
> treatment when network requests need per-request proxy selection.

**Scope / Trigger**

- Trigger: accounts or requests may route through different HTTP proxies
  (direct, custom per-account, or follow global setting). Each proxy
  requires a distinct `Dio` instance with its own `HttpClient` adapter.
- Mandatory when the same `DioClient` must serve multiple proxy contexts
  without recreating interceptors or losing connection pooling.

**Signatures**

```dart
class DioClient {
  final Map<String, Dio> _pool = {};
  final void Function(Dio) _configureInterceptors;

  /// Returns a cached Dio instance for the given proxy configuration.
  /// Same proxy → same instance; null proxy → direct/no-proxy instance.
  Dio getDio({ProxyConfig? proxy});

  /// Internal: builds a fresh Dio with the proxy wired into HttpClient.
  Dio _buildDio({ProxyConfig? proxy});
}

class ProxyConfig {
  final ProxyScheme scheme;  // http / https / socks5 (future)
  final String host;
  final int port;
  final String? username;
  final String? password;
}
```

Reference implementation:

- `lib/core/network/dio_client.dart` — `_pool`, `getDio`, `_buildDio`
- `lib/core/network/proxy_config.dart` — entity definition

**Contracts**

| Cache key | Dio instance behavior |
| --------- | --------------------- |
| `_directKey` (constant) | No proxy; direct connection |
| `'http://host:port'` | HTTP proxy without auth |
| `'https://host:port'` | HTTPS proxy without auth |
| Same key string | Same Dio instance (cached) |

| Platform | Adapter | Proxy support |
| -------- | ------- | ------------- |
| `kIsWeb == false` | `IOHttpClientAdapter` | Yes — via `findProxy` + `addProxyCredentials` |
| `kIsWeb == true` | `BrowserHttpClientAdapter` | No — browser controls proxy |

**Validation & Error Matrix**

| Condition | Result |
| --------- | ------ |
| `proxy == null` | Returns direct Dio instance |
| `proxy.host` empty | Treated as null → direct Dio |
| `proxy.port` invalid (≤0) | Throws `ArgumentError` in `_buildDio` |
| Auth fields partially set | Only applies `addProxyCredentials` when both `username` and `password` are non-empty |
| Web platform | Skips proxy config; returns a Dio with `BrowserHttpClientAdapter` |

**Good / Base / Bad Cases**

- **Good**: Repository calls `ProxyResolver.resolve(account, global)` once,
  passes the result to `ApiRequest(proxy: resolved)`, adapter calls
  `dioClient.getDio(proxy: request.proxy)`. Proxy is applied end-to-end.
- **Base**: No proxy configured anywhere. All calls use `getDio()` which
  returns the direct instance. Behavior unchanged from pre-pool design.
- **Bad**: Adapter caches `final _dio = dioClient.dio` in a field, then
  uses `_dio.get(...)` regardless of `request.proxy`. Proxy is silently
  ignored on that adapter.

**Tests Required**

- `test/core/network/dio_client_test.dart`:
  - `getDio()` returns same instance on repeated calls.
  - `getDio(proxy: p1)` and `getDio(proxy: p2)` return different instances when `p1 != p2`.
  - `getDio(proxy: sameProxy)` returns the cached instance.
  - Web platform returns `BrowserHttpClientAdapter`.
- `test/core/network/proxy_resolver_test.dart`:
  - Three-state priority: `direct` → null, `custom` → account proxy,
    `followGlobal` → global if enabled else null.

**Wrong vs Correct**

```dart
// Wrong — cached Dio ignores per-request proxy.
class CommonApiAdapter {
  final Dio _dio;  // captured in constructor
  Future<Result<T>> performRequest(ApiRequest request) async {
    final response = await _dio.get(request.path);  // proxy never applied
    ...
  }
}
```

```dart
// Correct — resolve Dio per request.
class CommonApiAdapter {
  final DioClient _client;
  Future<Result<T>> performRequest(ApiRequest request) async {
    final dio = _client.getDio(proxy: request.proxy);  // proxy-aware
    final response = await dio.get(request.path);
    ...
  }
}
```

**Implementation note — dart:io HttpClient proxy configuration**:

The `findProxy` callback returns a string in PAC-like format, NOT a full URL
with credentials:

```dart
// ❌ Wrong — dart:io does NOT parse user:pass from this string.
httpClient.findProxy = (uri) => 'PROXY user:pass@host:port';

// ✅ Correct — host:port in findProxy, credentials via addProxyCredentials.
httpClient.findProxy = (uri) => 'PROXY host:port';
if (username != null && password != null) {
  httpClient.addProxyCredentials(host, port, '', HttpClientBasicCredentials(username, password));
}
```

The realm parameter is typically empty string `''` for basic auth proxies.

### Pattern 9 — ProxyResolver Pure Function with Three-State Priority

**When to use**: an account can be in one of three proxy modes — direct
(no proxy), custom (account-specific proxy), or follow-global (defer to
global setting). The resolver must produce a single effective `ProxyConfig?`
without side effects.

**Reference implementation**:

- `lib/core/network/proxy_resolver.dart`

**Signature contract**:

```dart
class ProxyResolver {
  const ProxyResolver();

  /// Resolves the effective proxy configuration for an account.
  /// Returns null if the effective mode is "direct" (no proxy).
  ProxyConfig? resolve(Account account, GlobalProxySetting global) {
    return switch (account.proxyMode) {
      AccountProxyMode.direct => null,
      AccountProxyMode.custom => account.proxyConfig,
      AccountProxyMode.followGlobal => global.enabled ? global.config : null,
    };
  }
}

final proxyResolverProvider = Provider((ref) => const ProxyResolver());
```

**Rules**:
- Resolver is a **pure function** — no provider reads, no I/O, no mutation.
- Caller is responsible for obtaining `Account` and `GlobalProxySetting`.
- Riverpod provider exists only for convenient injection in tests and
  presentation layer; the resolver itself has no dependency on Riverpod.
- `GlobalProxySetting.enabled` gate is evaluated *inside* `followGlobal`
  branch — disabled global means fallback to null (direct).

**Don't**:
- Don't read `globalProxyProvider` inside `resolve`. That couples the
  domain function to presentation state and breaks testability.
- Don't return a default `ProxyConfig` with placeholder values — null means
  "no proxy", and a placeholder would cause connection failures.

**Required tests**:

- Direct mode returns null regardless of account.proxyConfig or global.
- Custom mode returns `account.proxyConfig` even if global is enabled.
- Follow-global with `global.enabled == true` returns `global.config`.
- Follow-global with `global.enabled == false` returns null.
- Priority order: `direct > custom > followGlobal` (earlier branches win).
