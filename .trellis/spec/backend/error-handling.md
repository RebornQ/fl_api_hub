# Error Handling

> How errors are handled in this project.

---

## Overview

There is no custom application error-handling layer implemented yet. The current repository is a minimal Flutter starter app with no remote I/O, persistence, or domain use cases.

Current observable behavior:

- local UI updates happen synchronously through `setState` in `lib/main.dart`
- there are no custom exception types in `lib/`
- there is no user-facing error rendering pattern established in the app code

---

## Error Types

No project-specific error types exist yet.

Current rule:

- Do not invent `AppError`, `Failure`, or transport exception hierarchies in docs until they exist in code.
- When network/storage/domain layers are added, define explicit typed failures in `core/error/` or feature domain layers and update this guide.

---

## Error Handling Patterns

No reusable pattern is established yet.

Current guidance for future implementation:

- keep low-level exceptions from network/storage layers out of widgets
- translate infrastructure failures into typed application/domain errors once those layers exist
- avoid burying try/catch blocks in UI build methods

This is guidance for future implementation, not a description of current code.

---

## API Error Responses

Not applicable right now.

This repository does not expose HTTP API endpoints or backend responses.

If the app later integrates with external APIs, document:

- transport error mapping
- empty/error/loading UI states
- retry rules
- user-safe error messaging

---

## Common Mistakes

- Catching broad exceptions in UI code without a recovery strategy.
- Documenting response/error envelopes before the network layer exists.
- Leaking raw infrastructure exceptions directly into presentation logic.
- Assuming a backend-service error model in a repository that is currently only a Flutter client.
