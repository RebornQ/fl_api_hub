# Component Guidelines

> How components are built in this project.

---

## Overview

Components in this repository are Flutter widgets, not React components. The current codebase uses both `StatelessWidget` and `StatefulWidget` in `lib/main.dart`:

- `MyApp` is the app shell and theme entrypoint.
- `MyHomePage` owns local interactive state.

Until feature folders are created, simple widgets may live close to the app entrypoint. As the app grows, reusable widgets should move into `lib/core/widgets/`, and feature-specific widgets should move into `lib/features/<feature>/presentation/`.

---

## Component Structure

Preferred widget file structure:

1. Imports
2. Public widget class
3. `const` constructor with `super.key`
4. Immutable configuration fields on the widget class
5. `build` method returning Material widgets
6. Separate `State` class only when local mutable UI state is needed

Current examples:

- `MyApp` in `lib/main.dart` shows the preferred structure for a simple stateless app shell.
- `MyHomePage` and `_MyHomePageState` in `lib/main.dart` show the current local-state widget pattern.

---

## Props Conventions

Flutter uses constructor parameters rather than React-style props.

- Prefer named parameters.
- Mark required inputs with `required`, e.g. `MyHomePage({super.key, required this.title})`.
- Store incoming widget configuration as `final` fields.
- Pass `Key` through `super.key`.
- If a widget needs too many constructor arguments, split the widget or introduce a typed model/config object instead of building a long parameter list.

---

## Styling Patterns

The current styling approach is Material Design based:

- Define app-level theme in `MaterialApp(theme: ThemeData(...))`.
- Read theme values via `Theme.of(context)`.
- Prefer `ColorScheme` and text theme tokens over ad-hoc styling.

Current examples in `lib/main.dart`:

- `ThemeData(colorScheme: ColorScheme.fromSeed(...))`
- `Theme.of(context).colorScheme.inversePrimary`
- `Theme.of(context).textTheme.headlineMedium`

Avoid scattering hard-coded visual values across widgets when a theme token already exists.

---

## Accessibility

Use Flutter Material widgets that provide baseline semantics by default, then add explicit affordances where needed.

- Provide a `tooltip` for icon-only actions.
- Use meaningful text labels.
- Prefer standard Material components before custom-painted widgets.

Current example:

- The `FloatingActionButton` in `lib/main.dart` includes `tooltip: 'Increment'`.

---

## Common Mistakes

- Letting `main.dart` keep growing after feature folders are introduced.
- Repeating styling inline instead of using `ThemeData` / `Theme.of(context)`.
- Using mutable public widget fields instead of `final` fields.
- Forgetting `const` constructors or `const` children where possible.
- Mixing app shell, feature UI, and future data logic into one widget file.

---

## Reusable Patterns

### Pattern — Full-Screen Form Page with Unsaved-Changes Guard

**When to use**: an edit/add screen with more than ~5 fields or
Section-grouped content. Prefer a full-screen `Scaffold` pushed via
`Navigator.push(MaterialPageRoute(fullscreenDialog: true))` over a
bottom sheet; the extra surface area plays better with BottomAppBar
actions and an AppBar close button.

**Reference implementation**:

- `lib/features/accounts/presentation/pages/account_edit_page.dart`

**Signature contract**:

```dart
class XEditPage extends ConsumerStatefulWidget {
  final X? entity;                         // null → add mode
  const XEditPage({super.key, this.entity});

  static Future<void> push(BuildContext context, {X? entity}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => XEditPage(entity: entity),
        fullscreenDialog: true,
      ),
    );
  }
}

@immutable
class _FormSnapshot {
  // Only the user-editable fields; id/createdAt/balance excluded so the
  // comparison is not skewed by derived data.
  // ... fields + operator == + hashCode
}

class _XEditPageState extends ConsumerState<XEditPage> {
  late final _FormSnapshot _initialSnapshot;
  _FormSnapshot get _currentSnapshot => _FormSnapshot.fromControllers(/* ... */);
  bool get _isDirty => _currentSnapshot != _initialSnapshot;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscardChanges();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: _requestClose,          // also runs confirm flow
          ),
          // ...
        ),
        body: SingleChildScrollView(child: Form(key: _formKey, child: ...)),
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomAppBar(child: Row(children: [...])),
        ),
      ),
    );
  }
}
```

**Rules**:
- The dirty check must compare a `_FormSnapshot` value object, NOT the
  domain entity. Comparing entities pulls in `id`, `createdAt`, cached
  `balance`, etc., which drift even when the user hasn't edited anything.
- Both pathways into "close" must run the same confirm flow:
  - PopScope (system back gesture / predictive back) via
    `onPopInvokedWithResult`.
  - Explicit close button via `IconButton(onPressed: _requestClose)`.
- `canPop: !_isDirty` flips the behavior — PopScope only intercepts when
  there are unsaved edits. A clean form returns immediately on back.
- `_requestClose` checks `_isDirty` first and only opens the dialog when
  needed; a pristine form pops without confirmation.
- Validate inside `_submit` via `Form.of(context).validate()` — do not
  rely on the primary button being disabled until all fields pass, as
  that hides which field is invalid.
- Placeholder actions (e.g. a future "auto-detect" button) must render
  in their final position from day one and respond with a SnackBar
  (`'该功能即将上线'`) — do not hide them behind feature flags, it
  desyncs UI from the design source of truth.
- Required fields whose domain entity uses a **sentinel** for "unfilled"
  (e.g. `username: ''`, `userId: -1`) must detect the sentinel during
  controller init and reflect it as an empty string:
  ```dart
  _userIdController = TextEditingController(
    text: (a != null && a.userId > 0) ? a.userId.toString() : '',
  );
  ```
  The paired validator then rejects empty / sentinel input, forcing the
  user to supply a real value before save. See
  `guides/cross-layer-thinking-guide.md` → **Mistake 6** for the full
  three-layer contract.
- Label required fields visibly by appending ` *` to the `labelText`
  (e.g. `labelText: '站点 URL *'`). Do not rely on the validator alone
  to communicate that a field is mandatory — the asterisk is the user's
  pre-submit cue.

**Don't**:
- Don't reach for `showModalBottomSheet` when the field count grows past
  ~5 or when there are ≥3 footer actions. Sheets crop the form, fight
  the keyboard, and make BottomAppBar action rows impossible.
- Don't scatter "token modified" booleans across the state. If the user
  touches the field, let the snapshot comparison handle it.

**Required tests** (widget):
- Edit mode pre-fills every field from the injected entity.
- Add mode renders the "add" primary button label and empty defaults.
- `_isDirty` detection: enter text in one field → back gesture shows
  the discard dialog; discard returns to the list.
- Conditional footer affordances (e.g. managed-only rocket_launch) show
  iff the site type flag says so.
- Placeholder actions surface the "即将上线" SnackBar and do not mutate
  state.
- Submit calls the expected notifier method (`create` vs `update`) with
  the right id semantics.

---

### Pattern — Resizable Split Pane with Persisted Ratio

**When to use**: master-detail layouts on widescreen (≥900px) where the
user may want to adjust the left/right panel balance.

**Reference implementation**:

- `lib/core/widgets/split_pane.dart`
- `lib/core/storage/split_pane_provider.dart`

**Signature contract**:

```dart
/// Provider for global split ratio (persisted to Hive).
final splitPaneRatioProvider = NotifierProvider<SplitPaneRatioNotifier, double>(
  SplitPaneRatioNotifier.new,
);

/// Reusable split-pane widget.
class SplitPane extends StatefulWidget {
  final double ratio;                      // 0.3–0.5, default 0.4
  final ValueChanged<double>? onRatioChanged;
  final Widget leftChild;
  final Widget rightChild;

  const SplitPane({
    required this.leftChild,
    required this.rightChild,
    this.ratio = 0.4,
    this.onRatioChanged,
    super.key,
  });
}

// Usage in page:
SplitPane(
  ratio: ref.watch(splitPaneRatioProvider),
  onRatioChanged: (r) =>
      ref.read(splitPaneRatioProvider.notifier).setRatio(r),
  leftChild: const MasterList(),
  rightChild: const DetailPanel(),
)
```

**Rules**:
- Ratio is clamped to a narrow range (30%–50%) to prevent either panel
  from becoming unusably narrow or wide.
- Visual feedback: three divider states with distinct colors:
  - Default: `outlineVariant` 40% alpha (subtle)
  - Hover: `outline` (visible)
  - Dragging: `primary` (prominent)
- Persist only on drag end (`onHorizontalDragEnd`), not during live
  resize, to avoid excessive I/O.
- Use `MouseRegion(cursor: SystemMouseCursors.resizeColumn)` to signal
  draggable affordance on hover.
- The widget owns local `_isHovering` / `_isDragging` state; the parent
  connects it to a global provider for persistence.
- Reuse the same provider across all pages so the user's preference is
  consistent app-wide.

**Don't**:
- Don't persist on every `onHorizontalDragUpdate` — it triggers too
  frequently during a single drag gesture.
- Don't hardcode ratio in multiple pages; centralize via provider.
- Don't use `shared_preferences` when the project already has a
  Hive-based `KeyValueStore` — prefer existing infrastructure.

---

### Pattern — Async DropdownButtonFormField with Deduplication

**When to use**: a `DropdownButtonFormField` whose items come from an async
source (API call, Riverpod provider). The selected value may have been set
before the item list loaded (e.g. editing an entity whose group name came
from a previous API response).

**Reference implementation**:

- `lib/features/keys/presentation/widgets/key_form_sheet.dart`

**Rules**:

- Deduplicate items with `Set<String>` before building `DropdownMenuItem`s.
  API responses may contain duplicates across different endpoints.
- Sync the selected value with the item list: if `_selectedValue` is not in
  the deduplicated set, compute an `effectiveValue` as `null` instead of
  forcing it into the list. Forcing causes assertion errors.
- Sort items alphabetically for a consistent UX.
- For loading state, render a disabled `DropdownButtonFormField` with a
  placeholder item ("加载中...") instead of `CircularProgressIndicator`
  — this avoids layout jumps when data arrives.
- Use `initialValue` (not `value`) for `DropdownButtonFormField` to avoid
  build-during-frame issues in Flutter ≥3.33.

**Don't**:

- Don't add `_selectedValue` to the item list as a fallback — this
  desyncs the dropdown from the API and confuses users.
- Don't use `CircularProgressIndicator` for loading state in dropdowns —
  the layout shift causes visual jank.
