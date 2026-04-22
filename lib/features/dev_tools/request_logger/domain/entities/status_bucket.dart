/// Quick-filter buckets shown on the request logger list page.
///
/// The buckets intentionally collapse the full HTTP status range into a
/// small, debug-friendly set: successes include 2xx **and** 3xx (Dio follows
/// redirects by default anyway), while [error] covers transport failures
/// such as timeouts / connection loss / cancellation where no status code
/// is available.
library;

/// Status quick-filter buckets for the request logger list.
enum StatusBucket {
  /// No filter — show all entries.
  all,

  /// 2xx + 3xx responses (final status after redirect follows).
  success,

  /// 4xx client errors.
  clientError,

  /// 5xx server errors.
  serverError,

  /// Transport failures — no status code (timeout / network / cancel).
  error,
}
