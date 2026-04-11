# Logging Guidelines

> How logging is done in this project.

---

## Overview

No structured logging library or project-level logging convention is implemented yet.

Evidence:

- `pubspec.yaml` does not include a logging package.
- `lib/main.dart` contains no logging calls.
- `analysis_options.yaml` inherits `flutter_lints`; no project-specific logging rule is defined.

Until logging is introduced, avoid documenting imaginary log levels or formats as if they are already enforced.

---

## Log Levels

No log-level policy is currently implemented.

Future expectation once logging is added:

- use a consistent logger abstraction rather than scattered `print` calls
- define when debug/info/warn/error should be emitted
- document environment-specific behavior if logs differ between debug and release builds

---

## Structured Logging

Not implemented.

There is currently no schema for fields such as request ID, feature name, user ID, or error code.

When logging is introduced, update this file with the actual logger package and field conventions used by the project.

---

## What to Log

Current guidance for future work:

- important app lifecycle milestones
- recoverable and unrecoverable failures
- network request failures once a network layer exists
- feature-specific diagnostics that help reproduce issues without exposing sensitive data

---

## What NOT to Log

Even before a logger exists, these constraints already apply:

- never log API keys, tokens, or secrets
- never commit sensitive runtime configuration to source control
- prefer build-time configuration such as `--dart-define`, as documented in `CLAUDE.md`

---

## Common Mistakes

- Using undocumented `print` statements as a permanent logging strategy.
- Inventing structured logging requirements before a logging package is chosen.
- Logging secrets or user-sensitive payloads.
- Confusing Flutter debug output with an intentional application logging standard.
