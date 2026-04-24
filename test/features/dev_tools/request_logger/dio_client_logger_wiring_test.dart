import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/dio_client.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';

/// Verifies that [dioClientProvider] attaches / detaches the
/// [RequestLoggerInterceptor] dynamically based on
/// [requestLoggerEnabledProvider].
void main() {
  group('dioClientProvider logger wiring', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    int loggerCount(DioClient client) =>
        client.dio.interceptors.whereType<RequestLoggerInterceptor>().length;

    test('switch off by default → only AuthInterceptor is present', () {
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 0);
      // AuthInterceptor is always present so total >= 1.
      expect(client.dio.interceptors.length, greaterThanOrEqualTo(1));
    });

    test('toggling switch on attaches exactly one logger', () {
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 0);

      container.read(requestLoggerEnabledProvider.notifier).state = true;

      expect(loggerCount(client), 1);
    });

    test('toggling switch off detaches the logger', () {
      final client = container.read(dioClientProvider);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      expect(loggerCount(client), 1);

      container.read(requestLoggerEnabledProvider.notifier).state = false;

      expect(loggerCount(client), 0);
    });

    test('toggling on again does not double-attach', () {
      final client = container.read(dioClientProvider);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      container.read(requestLoggerEnabledProvider.notifier).state = false;
      container.read(requestLoggerEnabledProvider.notifier).state = true;

      expect(loggerCount(client), 1);
    });

    test('starting with switch on attaches logger on first read', () {
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 1);
    });
  });
}
