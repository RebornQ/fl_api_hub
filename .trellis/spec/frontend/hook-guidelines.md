# Hook Guidelines

> How hooks are used in this project.

---

## Overview

This project does **not** currently use React-style hooks or Flutter hook libraries. There are no hook-related dependencies in `pubspec.yaml`, and the only implemented stateful logic uses `StatefulWidget` + `setState` in `lib/main.dart`.

The target architecture says the project will use Riverpod, but that dependency is not installed yet. Until that happens, do not invent hook conventions that do not exist in the repository.

---

## Custom Hook Patterns

There are currently no custom hooks in the codebase.

Current rule:

- Keep local state inside a widget's `State` class when the state is truly local.
- When shared or testable state is introduced later, move it into explicit architecture constructs such as Riverpod providers/controllers rather than ad-hoc helper functions that mimic hooks.
- Do not add `flutter_hooks` or `hooks_riverpod` unless the dependency decision is made explicitly and `pubspec.yaml` is updated.

Evidence:

- `lib/main.dart` uses `_MyHomePageState` and `setState`.
- `pubspec.yaml` contains no hook package.

---

## Data Fetching

No data-fetching pattern exists yet.

- There is no Dio dependency in `pubspec.yaml`.
- There are no repositories, services, or providers in `lib/` yet.
- Do not fetch remote data directly in widgets as a permanent pattern.

When networking is added, the intended direction is:

- network client in `lib/core/network/`
- feature-specific data sources/repositories in `lib/features/<feature>/data/`
- state exposure to UI through Riverpod once that dependency is added

---

## Naming Conventions

No hook naming convention is established because hooks are not implemented.

Until a hook library is adopted:

- Do not create files named `use_*.dart` or functions named `use*`.
- Use descriptive widget state methods such as `_incrementCounter()` for local UI actions.
- When Riverpod is introduced, document provider naming separately in the state management guide and update this file.

---

## Common Mistakes

- Importing React mental models into Flutter before the required package exists.
- Hiding side effects in utility functions that behave like unofficial hooks.
- Introducing hook packages without also documenting where they fit in the architecture.
- Using local widget state as a substitute for planned shared application state.
