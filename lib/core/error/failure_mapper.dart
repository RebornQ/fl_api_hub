/// Maps raw exceptions into typed [AppException] instances.
///
/// Use [mapToAppException] in repository catch-blocks to normalize every
/// error before wrapping it in a [Result.Failure].
library;

import 'package:dio/dio.dart';

import 'app_exception.dart';

/// Converts any thrown [error] into an [AppException].
///
/// If [error] is already an [AppException] it is returned as-is.
/// Dio errors are mapped to [NetworkException] or [AuthException].
/// Everything else is wrapped in [UnknownException].
AppException mapToAppException(Object error, [StackTrace? stackTrace]) {
  if (error is AppException) return error;

  if (error is DioException) {
    return _mapDioException(error, stackTrace);
  }

  return UnknownException(
    message: error.toString(),
    originalError: error,
    stackTrace: stackTrace,
  );
}

/// Maps [DioException] to the most specific [AppException] subtype.
AppException _mapDioException(DioException e, StackTrace? stackTrace) {
  // 401 / 403 → authentication issue
  final statusCode = e.response?.statusCode;
  if (statusCode == 401 || statusCode == 403) {
    return AuthException(
      message: 'Authentication failed',
      statusCode: statusCode,
      originalError: e,
      stackTrace: stackTrace,
    );
  }

  final message = switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Connection timed out',
    DioExceptionType.connectionError => 'No internet connection',
    DioExceptionType.badResponse => 'Server error (${statusCode ?? "unknown"})',
    _ => 'Network error',
  };

  return NetworkException(
    message: message,
    statusCode: statusCode,
    originalError: e,
    stackTrace: stackTrace,
  );
}
