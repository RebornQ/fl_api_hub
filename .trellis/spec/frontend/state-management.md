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

**Don't**:
- Don't call the sibling cascade *after* deleting the primary record.
  An intermittent failure on step 2 leaves B with references to a
  non-existent A.
- Don't substitute `on catch` + retry on the UI side — fix the flow at
  the repository layer so every caller gets the same guarantee.
