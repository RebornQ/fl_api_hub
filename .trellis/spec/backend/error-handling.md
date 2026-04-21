# Error Handling

> How errors are handled in this project.

---

## Overview

Errors are handled through a **sealed exception hierarchy** (`AppException`) and a **discriminated union result type** (`Result<T>`). Every layer converts raw errors into typed `AppException` subtypes, and all repository/adapter methods return `Result<T>` instead of throwing, forcing callers to handle both success and failure explicitly.

---

## Error Types

Defined in `lib/core/error/app_exception.dart`:

| Type | When | Key Fields |
|------|------|------------|
| `NetworkException` | Timeout, no connection, HTTP error | `statusCode?` |
| `StorageException` | Hive / SecureStore failures | — |
| `AuthException` | 401/403, expired token, invalid credentials | `statusCode?` |
| `ValidationException` | Input validation failures | `fieldErrors?` |
| `UnknownException` | Anything not explicitly handled | — |

All carry `message`, `originalError?`, `stackTrace?`.

---

## Error Handling Patterns

### 1. Result<T> (lib/core/result/result.dart)

All repository/adapter methods return `Result<T>`:

```dart
// Caller pattern
result.when(
  onSuccess: (data) => /* handle success */,
  onFailure: (exception) => /* handle error */,
);
```

### 2. Failure Mapper (lib/core/error/failure_mapper.dart)

`mapToAppException(error, stackTrace)` converts raw errors:
- Already `AppException` → returned as-is
- `DioException` with 401/403 → `AuthException`
- `DioException` timeout → `NetworkException`
- Everything else → `UnknownException`

### 3. Adapter Error Pattern

In `CommonApiAdapter` and all `SiteAdapter` implementations:

```dart
try {
  final response = await dio.request(...);
  final apiResponse = ApiResponse.fromJson(response.data, Dto.fromJson);
  if (apiResponse.success && apiResponse.data != null) {
    return Success(apiResponse.data);
  }
  return Failure(NetworkException(message: apiResponse.message ?? 'Unknown'));
} on DioException catch (e, st) {
  return Failure(mapToAppException(e, st));
} catch (e, st) {
  return Failure(UnknownException(message: e.toString(), originalError: e, stackTrace: st));
}
```

### 4. Remote DataSource Layer

Remote data sources are **thin delegation layers** — they do NOT catch exceptions. They simply forward the `Result<T>` from the adapter.

---

## API Error Responses

Common/new-api envelope: `{"success": bool, "message": string, "data": T}`

- `success: false` → `Failure(NetworkException(message: apiResponse.message))`
- Dio 401/403 → `Failure(AuthException(statusCode: 401))`
- Dio timeout → `Failure(NetworkException(message: "Connection timed out"))`

---

## Per-Request Auth Error Flow

`AuthInterceptor` (`lib/core/network/auth_interceptor.dart`) reads auth context from `RequestOptions.extra`, populated by `CommonApiAdapter._request` / `_buildOptions` (`lib/core/network/adapters/common_api_adapter.dart`) from the current `ApiRequest` (`lib/core/network/api_request.dart`).

### Extras contract (source of truth)

| Extras key    | Source                   | Type     | Header written                       |
| ------------- | ------------------------ | -------- | ------------------------------------ |
| `apiBaseUrl`  | `ApiRequest.baseUrl`     | `String` | Sets `options.baseUrl`               |
| `apiAuthToken`| `ApiRequest.authToken`   | `String?`| See `apiAuthType` switch below       |
| `apiAuthType` | `ApiRequest.authType.name` | `String` | `accessToken` / `cookie` / `none`  |
| `apiUserId`   | `ApiRequest.userId`      | `int?`   | `New-API-User: $userId` when `> 0`  |

### Header injection matrix

| Condition                                              | Header                          |
| ------------------------------------------------------ | ------------------------------- |
| `apiAuthType == "accessToken"` AND `apiAuthToken != ""` | `Authorization: Bearer $token` |
| `apiAuthType == "cookie"` AND `apiAuthToken != ""`     | `Cookie: session=$token`        |
| `apiAuthType == "none"` (or token empty / missing)      | — (no auth header)              |
| `apiUserId != null && apiUserId > 0`                    | `New-API-User: $userId`         |
| `apiUserId == null / == 0 / < 0` (sentinel `-1`)        | — (omit; relies on token-only)  |

The two injections are **orthogonal**: Cookie-authenticated requests also receive `New-API-User` when a positive `userId` is present. This is required because New API and most of its forks validate the user id in the header even when the caller is already authenticated via Bearer / Cookie.

### Good / Base / Bad cases

**Good** — account saved with real upstream id:
```dart
ApiRequest(
  baseUrl: 'https://example.com',
  authToken: 'sk-abc',
  authType: AuthType.accessToken,
  userId: 42,
) // → Authorization: Bearer sk-abc + New-API-User: 42
```

**Base** — Cookie-auth managed site (New API fork that also requires id):
```dart
ApiRequest(
  baseUrl: 'https://example.com',
  authToken: 'sess-xyz',
  authType: AuthType.cookie,
  userId: 7,
) // → Cookie: session=sess-xyz + New-API-User: 7
```

**Bad** — legacy / unfilled account (userId still at sentinel):
```dart
ApiRequest(
  baseUrl: 'https://example.com',
  authToken: 'sk-abc',
  authType: AuthType.accessToken,
  userId: -1, // ← sentinel for "never filled"
) // → Authorization: Bearer sk-abc only; 401 likely on strict backends.
  // Fix: editor enforces userId > 0 on save; call detect flow to refill.
```

### Validation

- `AuthInterceptor` is stateless; it never reads outside `options.extra`. Every adapter method MUST go through `CommonApiAdapter._request` / `_buildOptions` so all four extras keys are set atomically.
- `ApiRequest.userId` is `int?`; do NOT use `0` as the "unset" marker — zero is explicitly omitted by the interceptor but the domain `Account.userId` uses `-1`.
- Failure of the `New-API-User` echo (stricter backends) surfaces as Dio 401 → `AuthException` via `mapToAppException`. The `AccountsNotifier._checkSingle` path records it as `ReachabilityRecord.fail` with `FailCategory.http4xx` so the UI can show a red dot without crashing.

### Required tests (assertion points)

| Test                                                                    | File                                            | Asserts                                      |
| ----------------------------------------------------------------------- | ----------------------------------------------- | -------------------------------------------- |
| accessToken/cookie/none header injection                                | `test/core/network/auth_interceptor_test.dart`  | `Authorization` / `Cookie` present/absent    |
| `apiUserId > 0` → `New-API-User` written                                | 同上                                             | `headers['New-API-User'] == '$userId'`       |
| `apiUserId` null / `-1` / `0` / missing → header omitted                | 同上                                             | `headers.containsKey('New-API-User') == false` |
| Cookie authType + positive userId: both headers present                 | 同上                                             | Both headers set in the same request          |
| `AccountsNotifier._checkSingle` forwards `account.userId` → ApiRequest | `test/features/accounts/presentation/providers/accounts_notifier_test.dart` | `captureAny()` on `fetchAccountInfo`, assert `request.userId == account.userId` |

When this contract changes (e.g. a new extras key, or if Cookie sites stop needing `New-API-User`), update this matrix first, then the interceptor, then the test.

---

## Common Mistakes

- Catching broad exceptions in UI code without a recovery strategy.
- Using `throw` in repository/adapter methods instead of returning `Result.Failure`.
- Forgetting to handle the `Failure` branch of `Result.when()`.
- Leaking `DioException` past the adapter layer — always wrap with `mapToAppException`.
- Accessing `Result.dataOrNull` without checking `isSuccess` first.
