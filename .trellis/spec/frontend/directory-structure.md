# Directory Structure

> How frontend code is organized in this project.

---

## Overview

This repository is currently a minimal Flutter application. The implemented frontend code is concentrated in `lib/main.dart`, with one widget test in `test/widget_test.dart`. Platform bootstrap code lives in `android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/`.

The planned direction is documented in `CLAUDE.md`: Clean Architecture + Feature-First + Riverpod + Dio + Material Design 3. New code should move toward that structure, but documentation and implementation must clearly distinguish **current implemented state** from **target architecture**.

---

## Directory Layout

Current implemented layout:

```text
.
├── lib/
│   └── main.dart                 # current app entry and all UI logic
├── test/
│   └── widget_test.dart          # current widget smoke test
├── android/ ios/ web/ linux/ macos/ windows/
├── pubspec.yaml                  # dependencies and SDK constraints
├── analysis_options.yaml         # lint configuration
└── CLAUDE.md                     # repository rules and target architecture
```

Target application layout for new code (from `CLAUDE.md`):

```text
lib/
├── app/                          # app-level config: routes, theme, DI
├── core/                         # shared network, storage, error, utils, widgets
└── features/
    └── <feature>/
        ├── data/
        ├── domain/
        └── presentation/
```

---

## Module Organization

- Current state: `lib/main.dart` owns app bootstrap, theme setup, and screen logic in one file.
- New production code should live under `lib/`, not inside platform runner directories.
- App-wide configuration belongs in `lib/app/` once that directory exists.
- Shared cross-feature code belongs in `lib/core/`.
- Feature-specific code should be isolated under `lib/features/<feature>/` with `data/`, `domain/`, and `presentation/` subdirectories.
- Do not create an unrelated `src/` tree or ad-hoc top-level folders when `CLAUDE.md` already defines the target structure.

---

## Naming Conventions

- Use `snake_case.dart` for file names, matching the repository rule in `CLAUDE.md`.
- Use `UpperCamelCase` for widgets and types, e.g. `MyApp`, `MyHomePage`.
- Use `lowerCamelCase` for fields and methods.
- Use a leading underscore for private Dart members, e.g. `_counter`, `_incrementCounter`.
- Keep tests under `test/` and name them `*_test.dart`.

---

## Examples

- `lib/main.dart` — current single-file frontend structure.
- `test/widget_test.dart` — current test location and naming pattern.
- `CLAUDE.md` — target frontend directory layout for future feature work.
