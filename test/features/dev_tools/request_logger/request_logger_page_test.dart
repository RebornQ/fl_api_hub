import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_all_api_hub/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';
import 'package:fl_all_api_hub/features/dev_tools/request_logger/presentation/pages/request_logger_page.dart';
import 'package:fl_all_api_hub/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart';

RequestLogEntry _entry({
  required int id,
  int? statusCode = 200,
  String url = 'https://example.com/api',
  String method = 'GET',
  Duration elapsed = const Duration(milliseconds: 42),
}) {
  final now = DateTime.now();
  return RequestLogEntry(
    id: id,
    startedAt: now,
    endedAt: now,
    elapsed: elapsed,
    method: method,
    url: url,
    requestHeaders: const {},
    statusCode: statusCode,
  );
}

Widget _wrap({required ProviderContainer container, Size? size}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size ?? const Size(400, 800)),
        child: const RequestLoggerPage(),
      ),
    ),
  );
}

void main() {
  group('RequestLoggerPage — empty states', () {
    testWidgets('switch off + empty buffer shows "尚未开启" message',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container: container));

      expect(find.textContaining('请求记录器尚未开启'), findsOneWidget);
    });

    testWidgets('switch on + empty buffer shows "等待请求" message',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLoggerEnabledProvider.notifier).state = true;

      await tester.pumpWidget(_wrap(container: container));

      expect(find.textContaining('等待请求中'), findsOneWidget);
    });
  });

  group('RequestLoggerPage — list rendering', () {
    testWidgets('renders tile for each buffer entry with URL path visible',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      container
          .read(requestLogBufferProvider.notifier)
          .add(_entry(id: 1, url: 'https://api.test/v1/login'));
      container
          .read(requestLogBufferProvider.notifier)
          .add(_entry(id: 2, url: 'https://api.test/v1/users/42'));

      await tester.pumpWidget(_wrap(container: container));

      expect(find.text('/v1/login'), findsOneWidget);
      expect(find.text('/v1/users/42'), findsOneWidget);
      // Method badge.
      expect(find.text('GET'), findsNWidgets(2));
    });
  });

  group('RequestLoggerPage — clear action', () {
    testWidgets('clear icon + confirm empties the buffer', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      container.read(requestLogBufferProvider.notifier).add(_entry(id: 1));

      await tester.pumpWidget(_wrap(container: container));
      await tester.tap(find.byTooltip('清空记录'));
      await tester.pumpAndSettle();

      // Confirm dialog visible.
      expect(find.text('清空请求记录？'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '清空'));
      await tester.pumpAndSettle();

      expect(container.read(requestLogBufferProvider), isEmpty);
    });

    testWidgets('clear icon disabled when nothing to clear', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container: container));

      final clearBtn = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_sweep_outlined),
      );
      expect(clearBtn.onPressed, isNull);
    });
  });

  group('RequestLoggerPage — layout', () {
    testWidgets('wide layout renders VerticalDivider separator', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      container.read(requestLogBufferProvider.notifier).add(_entry(id: 1));

      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        container: container,
        size: const Size(1800, 1200),
      ));

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('narrow layout does not render VerticalDivider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(requestLoggerEnabledProvider.notifier).state = true;
      container.read(requestLogBufferProvider.notifier).add(_entry(id: 1));

      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrap(
        container: container,
        size: const Size(400, 800),
      ));

      expect(find.byType(VerticalDivider), findsNothing);
    });
  });

  group('RequestLoggerPage — in-app switch', () {
    testWidgets('AppBar switch toggles requestLoggerEnabledProvider',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container: container));
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      expect(container.read(requestLoggerEnabledProvider), isTrue);
    });
  });
}
