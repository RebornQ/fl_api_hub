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
