import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/dev_tools/request_logger/data/utils/body_serializer.dart';

void main() {
  group('serializeRequestBody', () {
    test('returns null for null input', () {
      expect(serializeRequestBody(null), isNull);
    });

    test('encodes Map with jsonEncode', () {
      final out = serializeRequestBody({'foo': 'bar', 'n': 1});
      expect(out, '{"foo":"bar","n":1}');
    });

    test('encodes List with jsonEncode', () {
      expect(serializeRequestBody([1, 2, 3]), '[1,2,3]');
    });

    test('passes through plain String', () {
      expect(serializeRequestBody('raw=value'), 'raw=value');
    });

    test('summarises FormData without reading streams', () {
      final fd = FormData.fromMap({'field1': 'v1', 'field2': 'v2'});
      final out = serializeRequestBody(fd)!;
      expect(out.startsWith('<FormData:'), isTrue);
      expect(out.contains('fields=2'), isTrue);
      expect(out.contains('files=0'), isTrue);
    });

    test('truncates oversized String at 64 KB UTF-8 boundary', () {
      final big = 'a' * (kMaxBodyBytes + 1000);
      final out = serializeRequestBody(big)!;
      expect(out.length, lessThan(big.length));
      expect(out.contains('已截断'), isTrue);
      // Declared original size ≈ 65 KB (raw was kMaxBodyBytes + 1000 = 66536).
      expect(out.contains('65 KB'), isTrue);
    });

    test('small body below threshold is not truncated', () {
      final payload = 'x' * 1000;
      expect(serializeRequestBody(payload), payload);
    });
  });

  group('serializeResponseBody', () {
    test('returns null for null input', () {
      expect(serializeResponseBody(null), isNull);
    });

    test('encodes JSON-like Map when content-type missing', () {
      expect(serializeResponseBody({'ok': true}), '{"ok":true}');
    });

    test(
      'replaces binary body with placeholder when content-type is image',
      () {
        final raw = List<int>.filled(2048, 0);
        final out = serializeResponseBody(raw, contentType: 'image/png')!;
        expect(out, '<二进制数据, 2048 bytes>');
      },
    );

    test('accepts application/json content-type and decodes', () {
      expect(
        serializeResponseBody({
          'hello': 'world',
        }, contentType: 'application/json; charset=utf-8'),
        '{"hello":"world"}',
      );
    });

    test('decodes List<int> as UTF-8 for text responses', () {
      final bytes = utf8.encode('{"ok":true}');
      expect(
        serializeResponseBody(bytes, contentType: 'application/json'),
        '{"ok":true}',
      );
    });

    test('text/* content types are treated as textual', () {
      expect(
        serializeResponseBody('plain text', contentType: 'text/plain'),
        'plain text',
      );
    });

    test('truncation applies to response bodies too', () {
      final big = 'b' * (kMaxBodyBytes + 100);
      final out = serializeResponseBody(big, contentType: 'text/plain')!;
      expect(out.contains('已截断'), isTrue);
    });
  });
}
