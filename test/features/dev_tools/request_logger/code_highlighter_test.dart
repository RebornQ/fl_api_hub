import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/dev_tools/request_logger/presentation/utils/code_highlighter.dart';

void main() {
  group('detectLanguage', () {
    test('returns json for application/json content-type', () {
      expect(detectLanguage('application/json', ''), 'json');
    });

    test('returns json for application/json; charset=utf-8', () {
      expect(detectLanguage('application/json; charset=utf-8', ''), 'json');
    });

    test('returns json for text/json content-type', () {
      expect(detectLanguage('text/json', ''), 'json');
    });

    test('returns xml for application/xml content-type', () {
      expect(detectLanguage('application/xml', ''), 'xml');
    });

    test('returns xml for text/xml content-type', () {
      expect(detectLanguage('text/xml', ''), 'xml');
    });

    test('returns xml for text/html content-type', () {
      expect(detectLanguage('text/html', ''), 'xml');
    });

    test('returns xml for application/xhtml+xml content-type', () {
      expect(detectLanguage('application/xhtml+xml', ''), 'xml');
    });

    test('returns plaintext for text/plain content-type', () {
      expect(detectLanguage('text/plain', ''), 'plaintext');
    });

    test('returns plaintext for form-urlencoded content-type', () {
      expect(
        detectLanguage('application/x-www-form-urlencoded', ''),
        'plaintext',
      );
    });

    test(
      'returns json by body-sniffing when content-type is null and body is JSON object',
      () {
        expect(detectLanguage(null, '{"key": "value"}'), 'json');
      },
    );

    test(
      'returns json by body-sniffing when content-type is null and body is JSON array',
      () {
        expect(detectLanguage(null, '[1, 2, 3]'), 'json');
      },
    );

    test('returns xml by body-sniffing when body starts with <', () {
      expect(detectLanguage(null, '<html><body></body></html>'), 'xml');
    });

    test(
      'returns plaintext when content-type is null and body is not JSON or XML',
      () {
        expect(detectLanguage(null, 'just some plain text'), 'plaintext');
      },
    );

    test('does not misdetect curly-brace non-JSON as json', () {
      // Starts with { but is not valid JSON.
      expect(detectLanguage(null, '{not valid json}'), 'plaintext');
    });

    test('handles empty content-type gracefully', () {
      expect(detectLanguage('', '{"a":1}'), 'json');
    });

    test('content-type detection is case-insensitive', () {
      expect(detectLanguage('Application/JSON', ''), 'json');
      expect(detectLanguage('TEXT/HTML', ''), 'xml');
    });
  });

  group('prettyPrintJson', () {
    test('pretty-prints a compact JSON object with 2-space indent', () {
      final input = '{"name":"test","value":42}';
      final result = prettyPrintJson(input);
      expect(result, contains('  "name": "test"'));
      expect(result, contains('  "value": 42'));
    });

    test('pretty-prints a JSON array', () {
      final input = '[1,2,3]';
      final result = prettyPrintJson(input);
      expect(result, contains('  1'));
    });

    test('returns original body on invalid JSON', () {
      const input = 'not json at all';
      expect(prettyPrintJson(input), input);
    });

    test('idempotent for already pretty-printed JSON', () {
      final input = const JsonEncoder.withIndent('  ').convert({'a': 1});
      expect(prettyPrintJson(input), input);
    });
  });

  group('buildHighlightedSpan', () {
    test('returns plain TextSpan for plaintext language', () {
      final span = buildHighlightedSpan(
        body: 'hello world',
        language: 'plaintext',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      expect(span.text, 'hello world');
      expect(span.children, isNull);
    });

    test('returns plain TextSpan for unknown language', () {
      final span = buildHighlightedSpan(
        body: 'hello world',
        language: 'python',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      expect(span.text, 'hello world');
    });

    test('returns plain TextSpan for bodies exceeding 50KB', () {
      // Build a string just over 50KB.
      final largeBody = 'x' * (50 * 1024 + 1);
      final span = buildHighlightedSpan(
        body: largeBody,
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      // Falls back to plain span for large bodies.
      expect(span.text, largeBody);
      expect(span.children, isNull);
    });

    test('returns highlighted TextSpan with children for small JSON', () {
      final span = buildHighlightedSpan(
        body: '{"key": "value"}',
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      // A highlighted span should have children (different token styles).
      expect(span.children, isNotNull);
      expect(span.children!.isNotEmpty, isTrue);
    });

    test('returns highlighted TextSpan with children for XML', () {
      final span = buildHighlightedSpan(
        body: '<root><item>text</item></root>',
        language: 'xml',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      expect(span.children, isNotNull);
      expect(span.children!.isNotEmpty, isTrue);
    });

    test('dark mode uses different theme than light mode', () {
      // We verify that both modes produce highlighted output (children)
      // and that the root styles differ. The root style carries the
      // theme's root color/backgroundColor.
      final lightSpan = buildHighlightedSpan(
        body: '{"key": "value"}',
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      final darkSpan = buildHighlightedSpan(
        body: '{"key": "value"}',
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: true,
      );

      // Both should produce highlighted output.
      expect(lightSpan.children, isNotNull);
      expect(darkSpan.children, isNotNull);

      // The root TextSpan style includes theme-specific colors.
      // Recursively collect all non-null colors from the span tree.
      List<Color?> collectColors(TextSpan span) {
        final colors = <Color?>[span.style?.color];
        for (final child in span.children?.cast<TextSpan>() ?? <TextSpan>[]) {
          colors.addAll(collectColors(child));
        }
        return colors;
      }

      final lightColors = collectColors(lightSpan).whereType<Color>().toList();
      final darkColors = collectColors(darkSpan).whereType<Color>().toList();

      // The highlighted output should contain colors, and they should differ
      // between light and dark themes.
      expect(lightColors, isNotEmpty);
      expect(darkColors, isNotEmpty);
      expect(lightColors.first, isNot(equals(darkColors.first)));
    });

    test('body at exactly 50KB boundary gets highlighted', () {
      // The guard is body.length > 50*1024, so a body of exactly 50*1024
      // characters should still be highlighted. Build a JSON string of
      // exactly 50*1024 characters.
      final innerPadding = '{"a":""}'.length; // 7 chars
      final padLength = 50 * 1024 - innerPadding;
      final body = '{"a":"${'x' * padLength}"}';
      expect(body.length, equals(50 * 1024));

      final span = buildHighlightedSpan(
        body: body,
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      expect(span.children, isNotNull);
      expect(span.children!.isNotEmpty, isTrue);
    });

    test('body just over 50KB boundary falls back to plain', () {
      final innerPadding = '{"a":""}'.length; // 7 chars
      final padLength = 50 * 1024 - innerPadding + 1;
      final body = '{"a":"${'x' * padLength}"}';
      expect(body.length, greaterThan(50 * 1024));

      final span = buildHighlightedSpan(
        body: body,
        language: 'json',
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        isDark: false,
      );
      // Falls back to plain span for oversized bodies.
      expect(span.children, isNull);
    });
  });
}
