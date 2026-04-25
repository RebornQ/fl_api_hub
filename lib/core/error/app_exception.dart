/// Typed exception hierarchy for the Fl API Hub application.
///
/// Every layer converts raw errors into one of these subtypes so that the
/// presentation layer can display user-friendly messages without knowing
/// about Dio, Hive, or any other infrastructure detail.
library;

/// Base class for all application-specific exceptions.
///
/// Each subclass carries a user-facing [message] and an optional
/// [originalError] for debugging / logging.
sealed class AppException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => '$runtimeType: $message';
}

/// Network-related failures (timeout, no connection, HTTP error).
final class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException({
    required super.message,
    this.statusCode,
    super.originalError,
    super.stackTrace,
  });
}

/// Local storage operation failures (Hive, SecureStorage).
final class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Authentication / authorization failures (expired token, invalid credentials).
final class AuthException extends AppException {
  final int? statusCode;

  const AuthException({
    required super.message,
    this.statusCode,
    super.originalError,
    super.stackTrace,
  });
}

/// Input validation failures.
final class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    this.fieldErrors,
    super.originalError,
    super.stackTrace,
  });
}

/// Any exception that is not explicitly handled.
final class UnknownException extends AppException {
  const UnknownException({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}

/// Backup/restore operation failures.
final class BackupException extends AppException {
  const BackupException({
    required super.message,
    super.originalError,
    super.stackTrace,
  });
}
