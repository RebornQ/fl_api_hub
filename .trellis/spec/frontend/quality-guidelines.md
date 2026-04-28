# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

The repository currently enforces baseline Flutter linting via `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
```

Code quality is therefore defined by:

- `dart format .` for formatting
- `flutter analyze` for static analysis
- `flutter test` for test execution

These commands are also referenced in `CLAUDE.md` / `AGENTS.md`.

---

## Forbidden Patterns

- Do not hand-format files instead of using `dart format .`.
- Do not ignore analyzer warnings without a documented reason.
- Do not claim unsupported architecture is already implemented.
- Do not place long-term feature code directly in `lib/main.dart` once proper feature directories are created.
- Do not add secrets or tokens to the repository; use `--dart-define` for build-time config as documented in `CLAUDE.md`.

---

## Required Patterns

- Keep Flutter code analyzable by `flutter analyze`.
- Format code with `dart format .`.
- Use `snake_case.dart` file names and standard Dart naming conventions.
- Prefer Material widgets and theme tokens over ad-hoc UI patterns.
- Add or update tests when changing user-visible widget behavior.

---

## Testing Requirements

Current test baseline:

- framework: `flutter_test`
- test location: `test/`
- naming: `*_test.dart`

Current example:

- `test/widget_test.dart` pumps `MyApp`, interacts with the floating action button, and verifies text updates.

Before considering frontend work complete, run:

- `dart format .`
- `flutter analyze`
- `flutter test`

---

## Gotchas

### Dart library-private members are inaccessible across files

Dart methods prefixed with `_` are **library-private** (file-scoped), not class-private. A subclass in a **different file** cannot call `_privateMethod()` even on its own superclass.

```
// onehub_adapter.dart
class OneHubAdapter extends CommonApiAdapter {
  // This method is library-private to onehub_adapter.dart.
  Future<Result<GroupListDto>> _fetchUserGroupMap(ApiRequest request) async { ... }
}

// donehub_adapter.dart (different file!)
class DoneHubAdapter extends OneHubAdapter {
  // ❌ Cannot call _fetchUserGroupMap() — it's invisible here.
  // ✅ Must mirror the method in this file, or extract to a shared mixin/utility.
}
```

**Prevention**: When designing an adapter hierarchy, mark overridable methods as `@protected` (no underscore) if subclasses in other files need to call them. Reserve `_` prefix for truly internal helpers.

---

## Code Review Checklist

- Does the change match the current repo state instead of imagined architecture?
- If the change moves toward target architecture, is that called out clearly and placed in the right directory?
- Are widget names, file names, and constructor patterns idiomatic Dart/Flutter?
- Are theme values reused instead of hard-coded repeatedly?
- Was widget behavior covered by at least a relevant test or an updated existing test?
- Were secrets avoided and config kept out of source control?
