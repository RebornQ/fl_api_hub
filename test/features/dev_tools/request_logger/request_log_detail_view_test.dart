import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_all_api_hub/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';
import 'package:fl_all_api_hub/features/dev_tools/request_logger/presentation/widgets/request_log_detail_placeholder.dart';

RequestLogEntry _entry({
  int id = 1,
  String method = 'POST',
  String url = 'https://api.example.com/v1/users',
  int? statusCode = 200,
  Map<String, dynamic>? query,
  Map<String, String>? requestHeaders,
  String? requestBody,
  Map<String, String>? responseHeaders,
  String? responseBody,
  String? errorType,
  String? errorMessage,
}) {
  final now = DateTime.now();
  return RequestLogEntry(
    id: id,
    startedAt: now,
    endedAt: now.add(const Duration(milliseconds: 42)),
    elapsed: const Duration(milliseconds: 42),
    method: method,
    url: url,
    query: query ?? const {},
    requestHeaders: requestHeaders ?? {'Content-Type': 'application/json'},
    requestBody: requestBody,
    statusCode: statusCode,
    responseHeaders: responseHeaders ?? {'Content-Type': 'application/json'},
    responseBody: responseBody,
    errorType: errorType,
    errorMessage: errorMessage,
  );
}

Widget _wrap(RequestLogEntry? entry) {
  return MaterialApp(
    home: Scaffold(
      body: RequestLogDetailView(entry: entry),
    ),
  );
}

void main() {
  group('RequestLogDetailView', () {
    testWidgets('shows placeholder when entry is null', (tester) async {
      await tester.pumpWidget(_wrap(null));
      expect(find.text('选择左侧的请求以查看详情'), findsOneWidget);
    });

    testWidgets('renders three SectionCards when entry is not null',
        (tester) async {
      await tester.pumpWidget(_wrap(_entry()));
      await tester.pumpAndSettle();

      expect(find.text('概览'), findsOneWidget);
      expect(find.text('REQUEST'), findsOneWidget);
      expect(find.text('RESPONSE'), findsOneWidget);
    });

    testWidgets('overview card shows method, URL, status, elapsed',
        (tester) async {
      await tester.pumpWidget(_wrap(_entry(
        method: 'GET',
        url: 'https://api.test/login',
        statusCode: 200,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('GET https://api.test/login'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget);
      expect(find.textContaining('42 ms'), findsOneWidget);
    });

    testWidgets('request card shows query params when present',
        (tester) async {
      await tester.pumpWidget(_wrap(_entry(
        query: {'page': '1', 'limit': '10'},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Query 参数'), findsOneWidget);
      expect(find.text('page'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('collapsible body shows expand button when > 10 lines',
        (tester) async {
      final longBody = List.generate(15, (i) => 'line $i').join('\n');
      await tester.pumpWidget(_wrap(_entry(requestBody: longBody)));
      await tester.pumpAndSettle();

      expect(find.text('展开'), findsOneWidget);

      await tester.tap(find.text('展开'));
      await tester.pumpAndSettle();

      expect(find.text('收起'), findsOneWidget);
    });

    testWidgets('response card shows error section when errorType present',
        (tester) async {
      await tester.pumpWidget(_wrap(_entry(
        statusCode: null,
        errorType: 'connectionTimeout',
        errorMessage: 'Connection timed out after 10s',
      )));
      await tester.pumpAndSettle();

      expect(find.text('错误信息'), findsOneWidget);
      expect(find.text('Type: connectionTimeout'), findsOneWidget);
      expect(find.text('Connection timed out after 10s'), findsOneWidget);
    });

    testWidgets('Copy as curl FAB copies to clipboard and shows SnackBar',
        (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (message) async {
          if (message.method == 'Clipboard.setData') {
            copiedText = message.arguments['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(_wrap(_entry(
        method: 'POST',
        url: 'https://api.test/login',
        requestBody: '{"user":"alice"}',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Copy as curl'));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText, contains('curl'));
      expect(copiedText, contains('POST'));
      expect(find.text('已复制 curl 命令到剪贴板'), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    testWidgets('empty request body shows placeholder', (tester) async {
      await tester.pumpWidget(_wrap(_entry(requestBody: null)));
      await tester.pumpAndSettle();

      expect(find.text('<无请求体>'), findsOneWidget);
    });

    testWidgets('empty response body shows different placeholder for errors',
        (tester) async {
      await tester.pumpWidget(_wrap(_entry(
        statusCode: null,
        responseBody: null,
        errorType: 'cancel',
      )));
      await tester.pumpAndSettle();

      expect(find.text('<请求失败，无响应>'), findsOneWidget);
    });
  });
}
