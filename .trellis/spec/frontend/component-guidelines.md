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
