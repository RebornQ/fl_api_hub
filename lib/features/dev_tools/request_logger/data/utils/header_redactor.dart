/// Header redaction utilities for the request logger.
///
/// The logger runs in every build flavor (including release), so any header
/// that might carry a credential must be masked **before** the entry leaves
/// the interceptor. Only the list below is treated as sensitive; new
/// credentials should be appended here whenever another interceptor starts
/// injecting them.
///
/// Masking rules:
/// - Values of length ≤ 8 are fully replaced with `*` of the same length,
///   so the reader cannot guess the original length precisely but still
///   sees "a non-empty value was present".
/// - Longer values keep their first 4 and last 4 characters with `****` in
///   the middle, giving enough context to tell tokens apart during
///   debugging while still hiding the payload.
library;

/// Canonical lower-case names of headers that must always be redacted.
///
/// Matching against incoming headers is case-insensitive.
const Set<String> kSensitiveHeaderNames = {
  'authorization',
  'cookie',
  'set-cookie',
  'new-api-user',
};

/// Masks a sensitive header value.
///
/// Returns an empty string for empty input. For values of length ≤ 8,
/// returns a string of `*` with the same length. Otherwise keeps the first
/// 4 and last 4 characters with `****` in between.
String maskSensitiveValue(String value) {
  if (value.isEmpty) return '';
  if (value.length <= 8) return '*' * value.length;
  return '${value.substring(0, 4)}****${value.substring(value.length - 4)}';
}

/// Returns a new `Map` with sensitive header values replaced by masked
/// equivalents; non-sensitive headers are passed through unchanged.
///
/// Matching is case-insensitive — a header named `AUTHORIZATION` or
/// `Authorization` is redacted the same as `authorization`. Original keys
/// are preserved in the result so UI display keeps the original casing.
///
/// The input map may have non-`String` values (Dio exposes `Map<String,
/// dynamic>` for headers); they are coerced via `toString()`.
Map<String, String> redactHeaders(Map<String, dynamic> headers) {
  final result = <String, String>{};
  headers.forEach((key, value) {
    final str = value?.toString() ?? '';
    final lowered = key.toLowerCase();
    if (kSensitiveHeaderNames.contains(lowered)) {
      result[key] = maskSensitiveValue(str);
    } else {
      result[key] = str;
    }
  });
  return result;
}
