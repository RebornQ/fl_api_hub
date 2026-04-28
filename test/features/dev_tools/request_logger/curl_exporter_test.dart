import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/dev_tools/request_logger/data/utils/curl_exporter.dart';
import 'package:fl_api_hub/features/dev_tools/request_logger/domain/entities/request_log_entry.dart';

RequestLogEntry _makeEntry({
  String method = 'GET',
  String url = 'https://example.com/api/resource',
  Map<String, String> requestHeaders = const {},
  String? requestBody,
}) {
  final now = DateTime.now();
  return RequestLogEntry(
    id: 1,
    startedAt: now,
    endedAt: now,
    elapsed: Duration.zero,
    method: method,
    url: url,
    requestHeaders: requestHeaders,
    requestBody: requestBody,
    statusCode: 200,
  );
}

void main() {
  group('exportAsCurl', () {
    test('GET command omits -X flag', () {
      final curl = exportAsCurl(_makeEntry());
      expect(curl.startsWith('curl'), isTrue);
      expect(curl.contains('-X GET'), isFalse);
      expect(curl.contains("'https://example.com/api/resource'"), isTrue);
    });

    test('POST command includes -X and body', () {
      final curl = exportAsCurl(
        _makeEntry(method: 'POST', requestBody: '{"foo":"bar"}'),
      );

      expect(curl.contains('-X POST'), isTrue);
      expect(curl.contains("--data-raw '{\"foo\":\"bar\"}'"), isTrue);
    });

    test('redacts sensitive headers during export', () {
      // Entry contains raw (unredacted) headers - curl export should redact them.
      final curl = exportAsCurl(
        _makeEntry(
          requestHeaders: {
            'Authorization': 'Bearer sk-1234567890abcdef',
            'Content-Type': 'application/json',
          },
        ),
      );

      // Authorization should be redacted (contain ****), not the raw value.
      expect(curl.contains('****'), isTrue);
      expect(curl.contains('sk-1234567890abcdef'), isFalse);
      expect(curl.contains("-H 'Content-Type: application/json'"), isTrue);
    });

    test('writes non-sensitive headers as-is', () {
      final curl = exportAsCurl(
        _makeEntry(
          requestHeaders: {
            'Content-Type': 'application/json',
            'X-Custom-Header': 'custom-value',
          },
        ),
      );

      expect(curl.contains("-H 'Content-Type: application/json'"), isTrue);
      expect(curl.contains("-H 'X-Custom-Header: custom-value'"), isTrue);
    });

    test('escapes single quotes inside values', () {
      final curl = exportAsCurl(
        _makeEntry(method: 'POST', requestBody: "it's here"),
      );

      // 'it's here' must become 'it'\''s here' under single-quote escaping.
      expect(curl.contains(r"it'\''s here"), isTrue);
    });

    test('FormData body becomes an inline comment, no --data flag', () {
      final curl = exportAsCurl(
        _makeEntry(
          method: 'POST',
          requestBody: '<FormData: fields=2, files=1>',
        ),
      );

      expect(curl.contains('--data'), isFalse);
      expect(curl.contains('FormData 不支持导出'), isTrue);
    });

    test('URL already containing query is not double-appended', () {
      final curl = exportAsCurl(
        _makeEntry(url: 'https://example.com/api?a=1&b=2'),
      );
      // Only one question mark should appear inside the quoted URL.
      final quoted = RegExp(r"'(https[^']+)'").firstMatch(curl)!.group(1)!;
      expect('?'.allMatches(quoted).length, 1);
    });
  });
}
