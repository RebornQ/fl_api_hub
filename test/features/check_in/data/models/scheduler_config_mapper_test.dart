import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/features/check_in/data/models/scheduler_config_mapper.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/scheduler_config.dart';

void main() {
  group('SchedulerConfigMapper', () {
    test('toMap/fromMap roundtrip preserves all fields', () {
      final config = SchedulerConfig(
        enabled: true,
        timeWindowStart: '07:00',
        timeWindowEnd: '11:00',
        retryIntervalMinutes: 15,
        maxRetries: 5,
      );

      final map = SchedulerConfigMapper.toMap(config);
      final restored = SchedulerConfigMapper.fromMap(map);

      expect(restored, equals(config));
      expect(restored.enabled, true);
      expect(restored.timeWindowStart, '07:00');
      expect(restored.timeWindowEnd, '11:00');
      expect(restored.retryIntervalMinutes, 15);
      expect(restored.maxRetries, 5);
    });

    test('fromMap with empty map returns all defaults', () {
      final restored = SchedulerConfigMapper.fromMap({});

      expect(restored.enabled, false);
      expect(restored.timeWindowStart, '08:00');
      expect(restored.timeWindowEnd, '10:00');
      expect(restored.retryIntervalMinutes, 30);
      expect(restored.maxRetries, 3);
    });

    test('fromMap with partial data uses defaults for missing keys', () {
      final map = {'enabled': true, 'maxRetries': 10};

      final restored = SchedulerConfigMapper.fromMap(map);

      expect(restored.enabled, true);
      expect(restored.timeWindowStart, '08:00');
      expect(restored.timeWindowEnd, '10:00');
      expect(restored.retryIntervalMinutes, 30);
      expect(restored.maxRetries, 10);
    });
  });
}
