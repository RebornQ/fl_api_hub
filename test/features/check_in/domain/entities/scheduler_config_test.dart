import 'package:flutter_test/flutter_test.dart';
import 'package:fl_all_api_hub/features/check_in/domain/entities/scheduler_config.dart';

void main() {
  group('SchedulerConfig', () {
    test('default constructor values', () {
      const config = SchedulerConfig();

      expect(config.enabled, false);
      expect(config.timeWindowStart, '08:00');
      expect(config.timeWindowEnd, '10:00');
      expect(config.retryIntervalMinutes, 30);
      expect(config.maxRetries, 3);
    });

    test('copyWith replaces specified fields and keeps others', () {
      const config = SchedulerConfig();
      final updated = config.copyWith(enabled: true, timeWindowEnd: '12:00');

      expect(updated.enabled, true);
      expect(updated.timeWindowStart, '08:00');
      expect(updated.timeWindowEnd, '12:00');
      expect(updated.retryIntervalMinutes, 30);
      expect(updated.maxRetries, 3);
    });

    test('equality is based on all fields', () {
      const configA = SchedulerConfig(
        enabled: true,
        timeWindowStart: '09:00',
        timeWindowEnd: '11:00',
        retryIntervalMinutes: 15,
        maxRetries: 5,
      );
      const configB = SchedulerConfig(
        enabled: true,
        timeWindowStart: '09:00',
        timeWindowEnd: '11:00',
        retryIntervalMinutes: 15,
        maxRetries: 5,
      );
      const configC = SchedulerConfig(
        enabled: false,
        timeWindowStart: '09:00',
        timeWindowEnd: '11:00',
        retryIntervalMinutes: 15,
        maxRetries: 5,
      );

      expect(configA, equals(configB));
      expect(configA.hashCode, equals(configB.hashCode));
      expect(configA, isNot(equals(configC)));
    });

    group('isWithinWindow', () {
      const config = SchedulerConfig(
        timeWindowStart: '08:00',
        timeWindowEnd: '10:00',
      );

      test('returns true when time is inside window', () {
        final now = DateTime(2026, 1, 1, 9, 0);
        expect(config.isWithinWindow(now), true);
      });

      test('returns false when time is outside window', () {
        final now = DateTime(2026, 1, 1, 11, 0);
        expect(config.isWithinWindow(now), false);
      });

      test('returns true at window start boundary', () {
        final now = DateTime(2026, 1, 1, 8, 0);
        expect(config.isWithinWindow(now), true);
      });

      test('returns true at window end boundary', () {
        final now = DateTime(2026, 1, 1, 10, 0);
        expect(config.isWithinWindow(now), true);
      });
    });

    test('toString contains key info', () {
      const config = SchedulerConfig(
        enabled: true,
        timeWindowStart: '09:00',
        timeWindowEnd: '11:00',
        retryIntervalMinutes: 20,
        maxRetries: 2,
      );

      final str = config.toString();

      expect(str, contains('true'));
      expect(str, contains('09:00'));
      expect(str, contains('11:00'));
      expect(str, contains('20'));
      expect(str, contains('2'));
    });
  });
}
