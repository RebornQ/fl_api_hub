/// Global auto-check-in scheduler configuration entity.
///
/// This is a single-document value object persisted in Hive. It controls
/// whether the foreground scheduler is active and defines the execution
/// window, retry strategy, and other global settings.
library;

/// Global auto-check-in scheduler configuration.
class SchedulerConfig {
  /// Whether auto check-in is globally enabled.
  final bool enabled;

  /// Start of the daily execution window in "HH:mm" format.
  /// Tasks will not execute before this time.
  final String timeWindowStart;

  /// End of the daily execution window in "HH:mm" format.
  /// Tasks will not execute after this time.
  final String timeWindowEnd;

  /// Minutes between retry attempts on failure.
  final int retryIntervalMinutes;

  /// Maximum number of retry attempts per task per day.
  final int maxRetries;

  const SchedulerConfig({
    this.enabled = false,
    this.timeWindowStart = '08:00',
    this.timeWindowEnd = '10:00',
    this.retryIntervalMinutes = 30,
    this.maxRetries = 3,
  });

  /// Creates a copy of this config with the given fields replaced.
  SchedulerConfig copyWith({
    bool? enabled,
    String? timeWindowStart,
    String? timeWindowEnd,
    int? retryIntervalMinutes,
    int? maxRetries,
  }) {
    return SchedulerConfig(
      enabled: enabled ?? this.enabled,
      timeWindowStart: timeWindowStart ?? this.timeWindowStart,
      timeWindowEnd: timeWindowEnd ?? this.timeWindowEnd,
      retryIntervalMinutes: retryIntervalMinutes ?? this.retryIntervalMinutes,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  /// Whether [now] falls within the configured execution window.
  bool isWithinWindow(DateTime now) {
    final start = _parseTime(timeWindowStart);
    final end = _parseTime(timeWindowEnd);
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.$1 * 60 + start.$2;
    final endMinutes = end.$1 * 60 + end.$2;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /// Parses a "HH:mm" string into (hour, minute).
  (int, int) _parseTime(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchedulerConfig &&
          enabled == other.enabled &&
          timeWindowStart == other.timeWindowStart &&
          timeWindowEnd == other.timeWindowEnd &&
          retryIntervalMinutes == other.retryIntervalMinutes &&
          maxRetries == other.maxRetries;

  @override
  int get hashCode => Object.hash(
    enabled,
    timeWindowStart,
    timeWindowEnd,
    retryIntervalMinutes,
    maxRetries,
  );

  @override
  String toString() =>
      'SchedulerConfig(enabled: $enabled, window: $timeWindowStart-$timeWindowEnd, '
      'retry: ${retryIntervalMinutes}min x$maxRetries)';
}
