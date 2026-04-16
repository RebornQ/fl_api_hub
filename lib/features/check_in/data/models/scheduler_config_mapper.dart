/// Mapper for [SchedulerConfig] serialization.
///
/// Converts between the domain entity and a Hive-compatible map.
/// Follows the same pattern as [CheckInTaskMapper].
library;

import '../../domain/entities/scheduler_config.dart';

/// Converts [SchedulerConfig] to and from JSON-compatible maps.
class SchedulerConfigMapper {
  const SchedulerConfigMapper._();

  /// Serializes a [SchedulerConfig] into a persistable map.
  static Map<String, dynamic> toMap(SchedulerConfig config) => {
    'enabled': config.enabled,
    'timeWindowStart': config.timeWindowStart,
    'timeWindowEnd': config.timeWindowEnd,
    'retryIntervalMinutes': config.retryIntervalMinutes,
    'maxRetries': config.maxRetries,
  };

  /// Deserializes a map back into a [SchedulerConfig].
  static SchedulerConfig fromMap(Map<String, dynamic> map) {
    return SchedulerConfig(
      enabled: map['enabled'] as bool? ?? false,
      timeWindowStart: map['timeWindowStart'] as String? ?? '08:00',
      timeWindowEnd: map['timeWindowEnd'] as String? ?? '10:00',
      retryIntervalMinutes: map['retryIntervalMinutes'] as int? ?? 30,
      maxRetries: map['maxRetries'] as int? ?? 3,
    );
  }
}
