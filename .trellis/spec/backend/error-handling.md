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

`AuthInterceptor` reads auth context from `RequestOptions.extra`:
- `apiBaseUrl` → overrides Dio baseUrl
- `apiAuthToken` + `apiAuthType` → injects `Authorization: Bearer` or `Cookie: session=`

If auth fails, the Dio 401 response is caught by the adapter's try/catch and converted to `AuthException` via `mapToAppException`.

---

## Common Mistakes

- Catching broad exceptions in UI code without a recovery strategy.
- Using `throw` in repository/adapter methods instead of returning `Result.Failure`.
- Forgetting to handle the `Failure` branch of `Result.when()`.
- Leaking `DioException` past the adapter layer — always wrap with `mapToAppException`.
- Accessing `Result.dataOrNull` without checking `isSuccess` first.
