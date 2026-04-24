import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/dev_tools/request_logger/data/utils/header_redactor.dart';

void main() {
  group('maskSensitiveValue', () {
    test('returns empty string for empty input', () {
      expect(maskSensitiveValue(''), '');
    });

    test('replaces short values with stars of the same length', () {
      expect(maskSensitiveValue('abc'), '***');
      expect(maskSensitiveValue('12345678'), '********');
    });

    test('keeps first and last 4 chars for long values', () {
      expect(maskSensitiveValue('abcdefghij'), 'abcd****ghij');
      expect(maskSensitiveValue('Bearer sk-1234567890xyz'), 'Bear****0xyz');
    });
  });

  group('redactHeaders', () {
    test('masks sensitive headers (case-insensitive lookup)', () {
      final redacted = redactHeaders({
        'Authorization': 'Bearer sk-1234567890',
        'COOKIE': 'session=abcdefghij',
        'new-api-user': '123456',
      });

      expect(redacted['Authorization'], isNot(equals('Bearer sk-1234567890')));
      expect(redacted['Authorization']!.contains('****'), isTrue);
      expect(redacted['COOKIE']!.contains('****'), isTrue);
      // Short value (≤8 chars) → fully starred.
      expect(redacted['new-api-user'], '******');
    });

    test('keeps original key casing in output', () {
      final redacted = redactHeaders({'Authorization': 'Bearer abcdefghij'});
      expect(redacted.containsKey('Authorization'), isTrue);
      expect(redacted.containsKey('authorization'), isFalse);
    });

    test('leaves non-sensitive headers untouched', () {
      final redacted = redactHeaders({
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'Dio/5.0',
      });

      expect(redacted['Content-Type'], 'application/json');
      expect(redacted['Accept'], 'application/json');
      expect(redacted['User-Agent'], 'Dio/5.0');
    });

    test('coerces non-string values with toString()', () {
      final redacted = redactHeaders({
        'X-Int-Header': 42,
        'X-Null-Header': null,
      });

      expect(redacted['X-Int-Header'], '42');
      expect(redacted['X-Null-Header'], '');
    });

    test('masks Set-Cookie response header variant', () {
      final redacted = redactHeaders({
        'Set-Cookie': 'session=abcdefghijklmnop; Path=/',
      });
      expect(redacted['Set-Cookie']!.contains('****'), isTrue);
      expect(redacted['Set-Cookie'], isNot(contains('abcdefghijkl')));
    });
  });
}
