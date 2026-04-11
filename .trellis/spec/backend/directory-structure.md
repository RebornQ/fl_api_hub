# Directory Structure

> How backend code is organized in this project.

---

## Overview

This repository does not currently contain implemented backend source code. It is a Flutter application bootstrap repository, and the only app code today is frontend code in `lib/main.dart` plus tests in `test/widget_test.dart`.

However, the target architecture documented in `CLAUDE.md` plans application-side data, domain, and integration layers under `lib/`. This guide documents the current reality and the intended placement for future app-side backend-like concerns such as networking, storage, repositories, and domain logic.

---

## Directory Layout

Current implemented state:

```text
.
├── lib/
│   └── main.dart
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

Planned internal application structure for non-UI logic (from `CLAUDE.md`):

```text
lib/
├── app/
├── core/
│   ├── network/
│   ├── storage/
│   ├── error/
│   └── utils/
└── features/
    └── <feature>/
        ├── data/
        ├── domain/
        └── presentation/
```

---

## Module Organization

Current rule:

- There are no backend modules yet.
- Do not document server routes, controllers, or service folders as if they already exist.

When app-side business logic is added:

- shared infrastructure belongs in `lib/core/`
- repository implementations and remote/local data sources belong in `lib/features/<feature>/data/`
- entities, repository interfaces, and use cases belong in `lib/features/<feature>/domain/`
- UI code stays in `presentation/`

This repository is not currently a standalone backend service.

---

## Naming Conventions

- Use `snake_case.dart` for files.
- Name feature folders by feature intent, not by technical layer alone.
- Keep cross-feature abstractions in `core/`, not copied into each feature.
- Do not invent `services/`, `api/`, or `repositories/` top-level roots outside the target structure unless the architecture decision changes first.

---

## Examples

- `CLAUDE.md` — source of truth for the planned app-side architecture.
- `lib/main.dart` — evidence that no backend module structure exists yet.
- `pubspec.yaml` — evidence that no networking/database dependency is installed yet.
