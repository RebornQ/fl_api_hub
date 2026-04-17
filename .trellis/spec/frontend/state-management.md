# State Management

> How state is managed in this project.

---

## Overview

The current implemented state management is minimal and local:

- `StatefulWidget` + `setState` are used for widget-local interaction state.
- There is no global state library installed yet.
- Riverpod is the target direction documented in `CLAUDE.md` and `.claude/rules/global.md`, but it is not present in `pubspec.yaml`.

Document future work carefully as target architecture, not as current behavior.

---

## State Categories

### Local UI State

Use local widget state for ephemeral interaction state that belongs to a single screen/widget.

Current example:

- `_counter` in `_MyHomePageState` at `lib/main.dart`
- `_incrementCounter()` calling `setState` in `lib/main.dart`

### Global App State

Not implemented yet.

There are currently no global providers, inherited state containers beyond Flutter defaults, or service locators in the application code.

### Server State

Not implemented yet.

There is no network layer, repository cache, or remote synchronization logic in the repository.

---

## When to Use Global State

Current rule for this repository stage:

- Do **not** introduce global state for simple single-screen demo behavior.
- Promote state out of a widget only when the same data is needed by multiple screens/features, must survive navigation boundaries, or represents business logic rather than display-only UI state.
- When promotion is needed, follow the documented target architecture and place shared state behind Riverpod once the dependency is added.

---

## Server State

No server-state approach is implemented yet.

Intended future flow from the target architecture:

- Dio-based client in `lib/core/network/`
- repositories/data sources in `lib/features/<feature>/data/`
- UI consumption through Riverpod providers in `presentation/`

Until those layers exist:

- avoid embedding future server-state assumptions into docs or code
- avoid calling APIs directly from widgets as the long-term pattern

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

**Rules**:
- Repository returns raw `Map` / `void` — **not** `Result<T>`. Missing or
  malformed records are normal, not errors.
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
             │         ├─ fetch() → Result<Dto>
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
