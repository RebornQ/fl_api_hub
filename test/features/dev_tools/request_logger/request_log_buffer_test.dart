import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/request_log_filter.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/status_bucket.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';

RequestLogEntry _entry({
  required int id,
  int? statusCode = 200,
  String url = 'https://example.com/api',
}) {
  final now = DateTime.now();
  return RequestLogEntry(
    id: id,
    startedAt: now,
    endedAt: now,
    elapsed: Duration.zero,
    method: 'GET',
    url: url,
    requestHeaders: const {},
    statusCode: statusCode,
  );
}

void main() {
  group('RequestLogBufferNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('starts empty', () {
      expect(container.read(requestLogBufferProvider), isEmpty);
    });

    test('add inserts in insertion order (oldest first)', () {
      final notifier = container.read(requestLogBufferProvider.notifier);
      notifier.add(_entry(id: 1));
      notifier.add(_entry(id: 2));
      notifier.add(_entry(id: 3));

      final list = container.read(requestLogBufferProvider);
      expect(list.map((e) => e.id).toList(), [1, 2, 3]);
    });

    test('capacity is 500 — 501st entry evicts the oldest', () {
      final notifier = container.read(requestLogBufferProvider.notifier);
      for (var i = 1; i <= kRequestLogBufferCapacity + 1; i++) {
        notifier.add(_entry(id: i));
      }
      final list = container.read(requestLogBufferProvider);
      expect(list.length, kRequestLogBufferCapacity);
      // Oldest (id 1) was evicted; newest (id 501) is kept.
      expect(list.first.id, 2);
      expect(list.last.id, kRequestLogBufferCapacity + 1);
    });

    test('clear empties the buffer', () {
      final notifier = container.read(requestLogBufferProvider.notifier);
      notifier.add(_entry(id: 1));
      notifier.add(_entry(id: 2));
      notifier.clear();

      expect(container.read(requestLogBufferProvider), isEmpty);
    });
  });

  group('filteredRequestLogsProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    void seed() {
      final notifier = container.read(requestLogBufferProvider.notifier);
      notifier.add(_entry(id: 1, statusCode: 200, url: 'https://a.test/users'));
      notifier.add(_entry(id: 2, statusCode: 404, url: 'https://b.test/login'));
      notifier.add(_entry(id: 3, statusCode: 500, url: 'https://a.test/pay'));
      notifier.add(_entry(id: 4, statusCode: null, url: 'https://b.test/down'));
    }

    test('returns newest-first by default', () {
      seed();
      final view = container.read(filteredRequestLogsProvider);
      expect(view.map((e) => e.id).toList(), [4, 3, 2, 1]);
    });

    test('keyword narrows by URL (case-insensitive)', () {
      seed();
      container.read(requestLogFilterProvider.notifier).state =
          const RequestLogFilter(keyword: 'A.TEST');
      final view = container.read(filteredRequestLogsProvider);
      expect(view.map((e) => e.id).toList(), [3, 1]);
    });

    test('statusBucket.error keeps only null-status entries', () {
      seed();
      container.read(requestLogFilterProvider.notifier).state =
          const RequestLogFilter(statusBucket: StatusBucket.error);
      final view = container.read(filteredRequestLogsProvider);
      expect(view.map((e) => e.id).toList(), [4]);
    });

    test('statusBucket.serverError keeps only 5xx entries', () {
      seed();
      container.read(requestLogFilterProvider.notifier).state =
          const RequestLogFilter(statusBucket: StatusBucket.serverError);
      final view = container.read(filteredRequestLogsProvider);
      expect(view.map((e) => e.id).toList(), [3]);
    });

    test('empty buffer yields empty list even with filter', () {
      container.read(requestLogFilterProvider.notifier).state =
          const RequestLogFilter(keyword: 'whatever');
      expect(container.read(filteredRequestLogsProvider), isEmpty);
    });
  });
}
