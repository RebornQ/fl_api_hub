# fix: widescreen check-in detail list not refreshing after FAB

## Goal

Fix the bug where the check-in detail panel (right side) in widescreen mode does not refresh after batch check-in via FAB, while the master list (left side) updates correctly.

## Root Cause

Race condition in `ref.listen` inside `CheckInDetailView.build()` (check_in_detail_view.dart:106-113):

1. `executeAll()` invalidates `latestResultPerAccountProvider` (FutureProvider)
2. It transitions `AsyncData → AsyncLoading → AsyncData(newData)` (async)
3. Widget rebuilds interleaves with this transition (`_isExecuting` flag + master list changes trigger rebuild)
4. When `ref.listen` re-registers during rebuild, the `AsyncLoading → AsyncData` transition may already be complete
5. Riverpod's `ref.listen` only fires on **subsequent** transitions → misses the change
6. `accountCheckInHistoryProvider` and `accountCheckInStatsProvider` never get invalidated → detail panel shows stale data

Narrow screen works because it explicitly invalidates providers before navigation (check_in_page.dart:394-395).

## Requirements

- Detail panel must refresh after FAB batch check-in in widescreen mode
- Must not break narrow-screen behavior
- Must not cause double-refresh flicker
- Must handle edge case: no account selected

## Acceptance Criteria

- [ ] In widescreen (≥900px), after clicking FAB check-in, the detail panel history list shows new results
- [ ] Stats card in detail panel updates with new counts
- [ ] Narrow screen behavior unchanged
- [ ] Pull-to-refresh and refresh FAB still work in widescreen
- [ ] No flicker or unnecessary loading states

## Technical Approach

Add explicit provider invalidation in `_executeAll()` after `executeAll()` returns, mirroring the narrow-screen pattern already in `_openDetail()`.

**Single file change:** `lib/features/check_in/presentation/pages/check_in_page.dart`

Insert after `final results = await ...` (line 483):

```dart
final selectedId = ref.read(selectedAccountIdProvider);
if (selectedId != null) {
  ref.invalidate(accountCheckInHistoryProvider(selectedId));
  ref.invalidate(accountCheckInStatsProvider(selectedId));
}
```

No new imports needed — both providers are already exported via `check_in_providers.dart`.

Keep `ref.listen` in `CheckInDetailView` unchanged — it still handles pull-to-refresh and refresh FAB scenarios.

## Decision (ADR-lite)

**Context**: The `ref.listen` mechanism in `CheckInDetailView` is fragile during batch execution due to widget rebuild interleaving.
**Decision**: Add explicit invalidation at the call site (`_executeAll`), consistent with narrow-screen pattern.
**Consequences**: `ref.invalidate` on an already-invalidated provider is idempotent, so no flicker. `CheckInNotifier` stays decoupled from UI providers.

## Out of Scope

- Refactoring the `ref.listen` mechanism
- Changes to `CheckInNotifier` or data layer
- Centralizing the master-detail layout pattern

## Verification

1. Run `flutter analyze` — must be clean
2. Launch app on tablet/desktop or resize to ≥900px
3. Select an account in the detail panel
4. Click FAB to execute batch check-in
5. Verify detail panel shows new results
6. Switch to narrow screen, test same flow — must still work
