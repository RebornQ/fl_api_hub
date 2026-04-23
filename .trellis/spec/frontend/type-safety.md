# Type Safety

> Type safety patterns in this project.

---

## Overview

This project uses Dart's static type system. Current code is simple but follows the standard typed Flutter style:

- typed widget classes (`StatelessWidget`, `StatefulWidget`, `State<MyHomePage>`)
- typed fields such as `final String title`
- typed method signatures such as `void main()` and `Widget build(BuildContext context)`

There is no separate runtime validation library in the repository yet.

---

## Type Organization

Current organization is file-local because the codebase is still small:

- widget classes and their fields are declared in `lib/main.dart`
- test code imports the public app entrypoint from `package:fl_all_api_hub/main.dart`

Target organization for future work:

- feature-specific models/entities in `lib/features/<feature>/domain/` or `data/`
- shared abstractions in `lib/core/`
- avoid dumping unrelated types into `main.dart` once the app structure expands

---

## Validation

No runtime validation library is currently installed.

Current approach:

- rely on Dart types and required named parameters for basic correctness
- keep constructor contracts explicit, e.g. `required this.title`

What this means in practice:

- do not document Zod/Yup-style patterns here; those do not apply to Dart
- if API or storage layers are added later, update this guide with the chosen decoding/validation pattern used in Dart models

---

## Common Patterns

- Prefer explicit types in public APIs and widget fields.
- Use `final` for immutable configuration values.
- Use private members with `_` when the symbol should stay file-private.
- Keep state typed, e.g. `int _counter = 0;`.
- Import app code through package imports in tests, as shown in `test/widget_test.dart`.

Current examples:

- `final String title;` in `lib/main.dart`
- `State<MyHomePage>` in `lib/main.dart`
- `testWidgets(..., (WidgetTester tester) async { ... })` in `test/widget_test.dart`

---

## Forbidden Patterns

- Do not use `dynamic` unless there is a strong interop reason.
- Do not rely on unchecked casts as a substitute for proper modeling.
- Do not add validation-library guidance that is not backed by current dependencies.
- Do not keep growing `main.dart` into a catch-all type container once domain/data layers are introduced.
