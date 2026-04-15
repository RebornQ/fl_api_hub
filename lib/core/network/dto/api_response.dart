/// Generic wrapper for the common/new-api JSON response envelope.
///
/// All common-compatible endpoints return:
/// ```json
/// {"success": true, "message": "", "data": {...}}
/// ```
/// This class deserializes that envelope and delegates the inner `data`
/// parsing to a type-specific [fromJson] callback.
library;

/// Typed envelope for common/new-api JSON responses.
class ApiResponse<T> {
  /// Whether the API call was successful.
  final bool success;

  /// Human-readable message from the server (may be empty).
  final String? message;

  /// Parsed response payload. `null` when [success] is `false`.
  final T? data;

  const ApiResponse({required this.success, this.message, this.data});

  /// Parses a raw JSON map into a typed [ApiResponse].
  ///
  /// [fromJson] converts the inner `data` map into type [T].
  /// When `success` is `false`, [data] is set to `null` regardless of
  /// the raw JSON content.
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final success = json['success'] as bool? ?? false;
    final message = json['message'] as String?;

    T? data;
    if (success) {
      final rawData = json['data'];
      if (rawData is Map<String, dynamic>) {
        data = fromJson(rawData);
      }
    }

    return ApiResponse<T>(success: success, message: message, data: data);
  }
}
