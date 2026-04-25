import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/dio_client.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/data/interceptors/request_logger_interceptor.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';

/// Verifies that [dioClientProvider] always has the
/// [RequestLoggerInterceptor] attached (the interceptor decides internally
/// what to do based on the enabled switch and correlation ID).
void main() {
  group('dioClientProvider logger wiring', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    int loggerCount(DioClient client) =>
        client.dio.interceptors.whereType<RequestLoggerInterceptor>().length;

    test('RequestLoggerInterceptor is always attached', () {
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 1);
    });

    test('toggling switch does not change interceptor count', () {
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 1);

      container.read(requestLoggerEnabledProvider.notifier).state = true;
      expect(loggerCount(client), 1);

      container.read(requestLoggerEnabledProvider.notifier).state = false;
      expect(loggerCount(client), 1);
    });

    test('starting with switch on still has exactly one logger', () {
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      final client = container.read(dioClientProvider);
      expect(loggerCount(client), 1);
    });
  });
}
