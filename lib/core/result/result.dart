/// Application-wide Result type for functional error handling.
///
/// Repositories and use cases return [Result<T>] instead of throwing
/// exceptions. This forces callers to handle both success and failure
/// explicitly, preventing unhandled exceptions at the UI layer.
library;

import '../error/app_exception.dart';

/// A discriminated union that represents either a success or a failure.
sealed class Result<T> {
  const Result();
}

/// Carries a successful [data] value.
final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Carries a failure with an [exception] describing what went wrong.
final class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

/// Convenience extensions on [Result].
extension ResultExtensions<T> on Result<T> {
  /// Pattern-match: invoke [onSuccess] for [Success] or [onFailure] for
  /// [Failure].
  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException exception) onFailure,
  }) {
    return switch (this) {
      Success(:final data) => onSuccess(data),
      Failure(:final exception) => onFailure(exception),
    };
  }

  /// The data if [Success], otherwise `null`.
  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Failure() => null,
  };

  /// Whether this result represents a success.
  bool get isSuccess => this is Success<T>;

  /// Returns [data] if [Success], otherwise [defaultValue].
  T getOrDefault(T defaultValue) => dataOrNull ?? defaultValue;
}
