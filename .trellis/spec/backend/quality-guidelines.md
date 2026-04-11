# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

There is no implemented backend/business-logic layer yet, so backend quality guidance in this repository is mostly about **how future non-UI layers should be introduced** while staying consistent with current project rules.

The currently enforced repository-wide quality checks are:

- `dart format .`
- `flutter analyze`
- `flutter test`

These are documented in `CLAUDE.md` / `AGENTS.md` and should apply to future data/domain/infrastructure code as well.

---

## Forbidden Patterns

- Do not document or implement backend conventions that are unsupported by current dependencies.
- Do not put repository/network/storage logic directly inside widgets.
- Do not add secrets to source control.
- Do not bypass analyzer feedback instead of fixing the underlying issue.
- Do not create architecture drift from the target Clean Architecture + Feature-First structure without an explicit decision.

---

## Required Patterns

When backend-like layers are added inside the Flutter app:

- keep domain, data, and presentation concerns separated
- place shared infrastructure under `lib/core/`
- keep feature-specific repositories/data sources inside each feature `data/` layer
- keep code formatted and analyzer-clean
- add tests for business logic as those layers appear

---

## Testing Requirements

Current baseline:

- test framework: `flutter_test`
- existing example: `test/widget_test.dart`

No domain/data tests exist yet, but future non-UI code should become easier to test than widget code. When such code is added:

- create focused tests under `test/`
- prefer testing use cases/repositories directly where possible
- keep widget tests for UI behavior, not for all business rules

---

## Code Review Checklist

- Is this documenting current reality accurately?
- If new backend-like code was added, is it placed in `core/` or feature `data/domain/` rather than widget files?
- Are package choices reflected in `pubspec.yaml` before the docs mention them?
- Are formatting, analysis, and tests still passing?
- Is secret/config handling aligned with `CLAUDE.md` guidance?
