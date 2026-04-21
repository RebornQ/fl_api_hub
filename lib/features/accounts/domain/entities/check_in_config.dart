/// Per-account check-in configuration.
///
/// Holds only the *static* per-account configuration: whether this account
/// participates in the automatic daily check-in, and an optional custom
/// check-in URL (for "welfare" / relay sites that run the check-in flow on
/// a different host than the API endpoint).
///
/// This is deliberately narrower than the `CheckInTask` entity under
/// `lib/features/check_in/`: `CheckInTask` owns the *scheduling* state
/// (next run time, last result, scheduler-level enable flag). The scheduler
/// should treat the final "should run" signal as the boolean AND of the
/// account's [autoCheckInEnabled] and the task's own `enabled` flag, so we
/// keep the two sources of truth non-overlapping.
library;

/// Immutable per-account check-in configuration.
class CheckInConfig {
  /// Whether this account participates in the automatic daily check-in.
  ///
  /// When `false`, the scheduler must skip this account regardless of the
  /// associated `CheckInTask.enabled` flag.
  final bool autoCheckInEnabled;

  /// Optional custom check-in URL.
  ///
  /// Used when the check-in endpoint lives on a different host than the API
  /// endpoint (e.g. a community welfare site). `null` means "use the site's
  /// default check-in flow" (if supported by the backend family).
  final String? customCheckInUrl;

  const CheckInConfig({this.autoCheckInEnabled = false, this.customCheckInUrl});

  /// Sentinel value representing "check-in disabled and no custom URL".
  static const CheckInConfig disabled = CheckInConfig();

  /// Creates a copy of this config with the given fields replaced.
  CheckInConfig copyWith({bool? autoCheckInEnabled, String? customCheckInUrl}) {
    return CheckInConfig(
      autoCheckInEnabled: autoCheckInEnabled ?? this.autoCheckInEnabled,
      customCheckInUrl: customCheckInUrl ?? this.customCheckInUrl,
    );
  }

  /// Explicit helper for callers that genuinely want to clear the URL.
  ///
  /// `copyWith` cannot distinguish "omitted" from "set to null" because
  /// nullable parameters fall back to `this.customCheckInUrl` via `??`.
  CheckInConfig withoutCustomCheckInUrl() {
    return CheckInConfig(
      autoCheckInEnabled: autoCheckInEnabled,
      customCheckInUrl: null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckInConfig &&
          autoCheckInEnabled == other.autoCheckInEnabled &&
          customCheckInUrl == other.customCheckInUrl;

  @override
  int get hashCode => Object.hash(autoCheckInEnabled, customCheckInUrl);

  @override
  String toString() =>
      'CheckInConfig(autoCheckInEnabled: $autoCheckInEnabled, '
      'customCheckInUrl: $customCheckInUrl)';
}
