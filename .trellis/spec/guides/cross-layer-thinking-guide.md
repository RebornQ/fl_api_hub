# Cross-Layer Thinking Guide

> **Purpose**: Think through data flow across layers before implementing.

---

## The Problem

**Most bugs happen at layer boundaries**, not within layers.

Common cross-layer bugs:
- API returns format A, frontend expects format B
- Database stores X, service transforms to Y, but loses data
- Multiple layers implement the same logic differently

---

## Before Implementing Cross-Layer Features

### Step 1: Map the Data Flow

Draw out how data moves:

```
Source → Transform → Store → Retrieve → Transform → Display
```

For each arrow, ask:
- What format is the data in?
- What could go wrong?
- Who is responsible for validation?

### Step 2: Identify Boundaries

| Boundary | Common Issues |
|----------|---------------|
| API ↔ Service | Type mismatches, missing fields |
| Service ↔ Database | Format conversions, null handling |
| Backend ↔ Frontend | Serialization, date formats |
| Component ↔ Component | Props shape changes |

### Step 3: Define Contracts

For each boundary:
- What is the exact input format?
- What is the exact output format?
- What errors can occur?

---

## Common Cross-Layer Mistakes

### Mistake 1: Implicit Format Assumptions

**Bad**: Assuming date format without checking

**Good**: Explicit format conversion at boundaries

### Mistake 2: Scattered Validation

**Bad**: Validating the same thing in multiple layers

**Good**: Validate once at the entry point

### Mistake 3: Leaky Abstractions

**Bad**: Component knows about database schema

**Good**: Each layer only knows its neighbors

### Mistake 4: Lazy Cascade on Read

**Bad**: Feature `A` deletes an entity but feature `B`'s records still
cite it; the read path "filters out orphan ids".

**Good**: Cascade on write. The deleting feature calls the sibling
repository to clean references **before** removing its own record.

→ See `frontend/state-management.md` → **Pattern 5 — Cross-Feature
Cascade Delete via Sibling Repository** for the executable contract and
wrong-vs-correct example.

### Mistake 5: Dual-Source Booleans Across Layers

**Bad**: The same "is-enabled" decision is persisted in two places
without a documented precedence rule — e.g. `Account.autoCheckInEnabled`
on the domain entity **and** `CheckInTask.enabled` inside the scheduler
storage. Whichever layer reads last sets the apparent truth, and the UI
toggle silently stops working whenever the other side was updated.

**Good**: Persist each concern in exactly one layer. If both must exist
(per-account opt-in vs scheduler-level kill-switch), document the
precedence as an explicit AND/OR:

```
scheduler should run on account a at time t
  ⇔ account.checkIn.autoCheckInEnabled   // user-level opt-in
    AND taskFor(a).enabled               // scheduler-level kill switch
```

Reference: `lib/features/accounts/domain/entities/check_in_config.dart`
library-level comment spells out the contract; the scheduler must honor
the AND semantics.

### Mistake 6: Non-null Required Field Backed by a Sentinel

**Bad**: Domain entity declares `final String? username` (nullable) and
each layer invents its own "is-this-really-filled?" check — editor
validator treats `null` vs `''` vs whitespace differently, mapper writes
`null` on empty input, UI displays `'null'` as a literal string, repo
code does `account.username ?? ''` in three places. The field becomes a
quiet bug factory because every layer makes its own assumption.

**Good**: Collapse "nullable + optional" into "non-null + sentinel", and
make the sentinel a *published* contract that every layer agrees on.
All three layers play a role:

```
┌──────────────────────┬──────────────────────────────────────────────┐
│ layer                │ responsibility                                │
├──────────────────────┼──────────────────────────────────────────────┤
│ domain (entity)      │ field type is non-null; doc comment declares │
│                      │ the sentinel value as "unfilled marker"       │
│ data   (mapper)      │ fromMap: null / unparseable → sentinel        │
│                      │ toMap:   sentinel → stored as-is (not null)   │
│ presentation (editor)│ initState: sentinel → controller.text = ''   │
│                      │ validator:  reject sentinel (demand re-entry) │
└──────────────────────┴──────────────────────────────────────────────┘
```

**Executable contract** — from this repo:

1. Entity declares the sentinel in the field doc:
   ```dart
   // lib/features/accounts/domain/entities/account.dart
   /// Account username as reported by the upstream site.
   /// Empty string `''` is the sentinel for "not yet filled".
   final String username;

   /// Account user id as reported by the upstream site.
   /// `-1` is the sentinel for "not yet filled".
   final int userId;
   ```

2. Mapper coerces legacy null payloads to the sentinel:
   ```dart
   // lib/features/accounts/data/models/account_mapper.dart
   username: (map['username'] as String?) ?? '',
   userId:   _readUserId(map['userId']),   // null → -1
   ```

3. Editor reflects the sentinel as empty input and validator rejects it:
   ```dart
   // lib/features/accounts/presentation/pages/account_edit_page.dart
   _userIdController = TextEditingController(
     text: (a != null && a.userId > 0) ? a.userId.toString() : '',
   );

   String? _validateUserId(String? value) {
     if (value == null || value.trim().isEmpty) return '请输入用户 ID';
     final parsed = int.tryParse(value.trim());
     if (parsed == null) return '请输入有效的数字';
     if (parsed <= 0)    return '请输入大于 0 的正整数';
     return null;
   }
   ```

**Validation / error matrix**:

| Input at persistence layer    | Entity value after fromMap | Editor shows | Save allowed? |
| ----------------------------- | -------------------------- | ------------ | ------------- |
| `'admin'` / `42`              | `'admin'` / `42`           | `'admin'` / `'42'` | yes     |
| `null` (legacy record)        | `''` / `-1` (sentinels)    | empty fields | **no** — validator demands re-entry |
| `'  '` (whitespace only)      | `'  '` (not re-sentinelled)| `'  '`       | **no** — `trim().isEmpty` check fails |
| `userId` stored as string `'42'` | `42` (parsed)           | `'42'`       | yes           |
| `userId` stored as `'oops'` (unparseable) | `-1` (sentinel)| empty        | **no**        |

**Good / Base / Bad cases**:

- **Good** — three-layer contract as above. Legacy rows load, user is
  forced to backfill before the write path sees a sentinel.
- **Base** — keep `String?`, add validator only in the editor. Works
  until another caller (API sync, import script) writes `null` back and
  the UI then renders `'null'` or crashes on `!`.
- **Bad** — make the field non-null with a "reasonable" default like
  `'unknown'` instead of a sentinel. Now the UI can't distinguish
  user-typed `'unknown'` from the placeholder, and validation is gone.

**Required tests and assertion points**:

- Mapper deserializes legacy payload with missing `username`/`userId`
  and asserts entity returns `''` / `-1` (not null).
  → `test/features/accounts/data/models/account_mapper_test.dart`
  `AccountMapper fromMap deserializes legacy payload without extended fields`.
- Mapper round-trips a sentinel value correctly:
  `toMap(entity) → fromMap(...)` produces the same sentinel.
- Editor widget test: opening the editor with a sentinel entity shows
  empty input in the corresponding field; save while empty surfaces the
  validator error and notifier is never called.
- Domain entity test: default constructor (no username/userId given)
  produces `''` / `-1`, not null.
  → `test/features/accounts/domain/entities/account_test.dart`
  `Account constructs with default values for extended fields`.

### Mistake 7: Inconsistent Proxy Propagation Across the Network Stack

**Bad**: An account is configured with a custom proxy, but the repository
constructs `ApiRequest` without a `proxy` field. The request goes through
`DioClient.dio` (the direct/no-proxy instance) instead of
`DioClient.getDio(proxy: resolvedProxy)`. The user sees a connection timeout
with no indication that the proxy was silently skipped.

**Good**: Every network call resolves the effective proxy via `ProxyResolver`
*before* constructing `ApiRequest`, and passes it through the full chain:

```
Repository (resolves proxy)
  → ApiRequest(proxy: resolvedProxy)
    → SiteAdapter.performRequest(request)
      → DioClient.getDio(proxy: request.proxy)
        → Dio with IOHttpClientAdapter(findProxy: ...)
```

**Prevention checklist**:
- When adding a new repository method that calls a SiteAdapter, always
  resolve proxy first: `ref.read(proxyResolverProvider).resolve(account, global)`.
- When adding a new SiteAdapter, use `dioClient.getDio(proxy: request.proxy)`
  — never cache a `Dio` reference locally.
- grep for `dioClient.dio` (the old singleton accessor) — it must have zero
  hits outside `DioClient` internals.

Reference: `lib/core/network/proxy_resolver.dart`,
`lib/core/network/dio_client.dart`.

---

## Checklist for Cross-Layer Features

Before implementation:
- [ ] Mapped the complete data flow
- [ ] Identified all layer boundaries
- [ ] Defined format at each boundary
- [ ] Decided where validation happens
- [ ] If one entity is referenced by id in another entity's list field:
      is there a **cascade delete** path? (Mistake 4)
- [ ] If the feature has an "enabled" / "active" flag: is it persisted
      in one place, or documented with explicit AND/OR semantics across
      layers? (Mistake 5)
- [ ] If a previously-nullable field is being tightened to non-null:
      is there a **sentinel contract** agreed across entity / mapper /
      editor? (Mistake 6)
- [ ] If the feature makes network requests: does every call site
      resolve proxy via `ProxyResolver` and pass it through
      `ApiRequest.proxy`? (Mistake 7)

After implementation:
- [ ] Tested with edge cases (null, empty, invalid)
- [ ] Verified error handling at each boundary
- [ ] Checked data survives round-trip
- [ ] If new fields were added to a persisted entity, verified that
      legacy payloads (missing those fields) still deserialize (Hive
      mapper fallback coverage).
- [ ] If a sentinel was introduced, verified legacy payloads rehydrate
      to the sentinel and the editor forces re-entry before save
      (Mistake 6).
- [ ] Grep for `dioClient.dio` — must return zero hits outside
      `DioClient` internals (Mistake 7).

---

## When to Create Flow Documentation

Create detailed flow docs when:
- Feature spans 3+ layers
- Multiple teams are involved
- Data format is complex
- Feature has caused bugs before
