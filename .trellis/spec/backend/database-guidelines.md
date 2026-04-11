# Database Guidelines

> Database patterns and conventions for this project.

---

## Overview

No database layer is implemented in this repository yet.

Evidence:

- `pubspec.yaml` has no persistence/database package.
- `lib/` contains only `main.dart`.
- There are no migrations, schema files, DAO/repository implementations, or local storage abstractions in the codebase.

Because this task is about documenting reality, this file must stay conservative until a real database choice is added.

---

## Query Patterns

No query pattern is established yet.

Current rule:

- Do not invent ORM/query conventions in documentation.
- When local persistence is introduced, document the actual package and query style used in the codebase.
- Keep data access out of widgets; place persistence code under `lib/core/storage/` or feature `data/` folders based on scope.

---

## Migrations

Not implemented.

- There is no migration tool configured.
- There are no schema version files in the repository.
- There is no documented migration command in `CLAUDE.md` or project scripts.

When a database package is adopted, update this file with:

- schema location
- migration generation/apply commands
- rollback strategy
- test fixtures or seed approach

---

## Naming Conventions

No database naming convention exists yet because there is no schema.

Future reminder only:

- choose one naming style and document it when the first schema lands
- keep model names, table/box names, and field names consistent across data/domain layers

---

## Common Mistakes

- Pretending a database standard exists before any package is selected.
- Putting persistence logic directly in widgets.
- Documenting migration commands that cannot be run in this repository.
- Mixing future architecture goals with current implementation facts.
