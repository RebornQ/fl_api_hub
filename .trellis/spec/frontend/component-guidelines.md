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
