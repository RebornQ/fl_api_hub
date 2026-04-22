import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/request_log_filter.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/domain/entities/status_bucket.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';
import 'package:all_api_hub_flutter/features/dev_tools/request_logger/presentation/widgets/request_log_filter_bar.dart';

RequestLogEntry _entry({required int id, int? statusCode, String? url}) {
  final now = DateTime.now();
  return RequestLogEntry(
    id: id,
    startedAt: now,
    endedAt: now,
    elapsed: Duration.zero,
    method: 'GET',
    url: url ?? 'https://example.com/api/$id',
    requestHeaders: const {},
    statusCode: statusCode,
  );
}

Widget _wrapFilterBar() {
  return const MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: EdgeInsets.all(8),
        child: RequestLogFilterBar(),
      ),
    ),
  );
}

void main() {
  group('RequestLogFilterBar', () {
    testWidgets('keyword input updates filter.keyword', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _wrapFilterBar()),
      );

      await tester.enterText(find.byType(TextField), 'login');
      await tester.pump();

      expect(
        container.read(requestLogFilterProvider).keyword,
        'login',
      );
    });

    testWidgets('bucket chip tap updates filter.statusBucket', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _wrapFilterBar()),
      );

      await tester.tap(find.textContaining('5xx'));
      await tester.pump();

      expect(
        container.read(requestLogFilterProvider).statusBucket,
        StatusBucket.serverError,
      );
    });

    testWidgets('bucket chip shows live count from buffer', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(requestLogBufferProvider.notifier)
          .add(_entry(id: 1, statusCode: 200));
      container
          .read(requestLogBufferProvider.notifier)
          .add(_entry(id: 2, statusCode: 500));
      container
          .read(requestLogBufferProvider.notifier)
          .add(_entry(id: 3, statusCode: null));

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _wrapFilterBar()),
      );

      expect(find.textContaining('全部 (3)'), findsOneWidget);
      expect(find.textContaining('2xx (1)'), findsOneWidget);
      expect(find.textContaining('5xx (1)'), findsOneWidget);
      expect(find.textContaining('错误 (1)'), findsOneWidget);
    });

    testWidgets('clear-search button resets keyword', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLogFilterProvider.notifier).state =
          const RequestLogFilter(keyword: 'abc');

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _wrapFilterBar()),
      );

      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pump();

      expect(container.read(requestLogFilterProvider).keyword, '');
    });
  });
}
