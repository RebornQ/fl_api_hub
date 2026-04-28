/// Syntax highlighting utilities for rendering request/response bodies.
///
/// Uses [re_highlight] (highlight.js Dart port) to produce [TextSpan] trees
/// that work with [SelectableText.rich] for copyable, highlighted code.
///
/// Language detection is based on Content-Type headers with a fallback to
/// body-sniffing (try JSON parse, else plain text).
///
/// Bodies larger than [_kMaxHighlightBytes] (50 KB) skip highlighting and
/// return a plain [TextSpan] to avoid UI jank.
library;

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/github.dart';
import 'package:re_highlight/styles/github-dark.dart';

/// Maximum body size (in bytes) that will be syntax-highlighted.
/// Larger bodies fall back to plain text to avoid jank.
const int _kMaxHighlightBytes = 50 * 1024;

/// Singleton [Highlight] instance with JSON and XML languages registered.
final _highlight = Highlight()
  ..registerLanguages({'json': langJson, 'xml': langXml});

/// Detects the highlight language from a Content-Type header value.
///
/// Returns `'json'`, `'xml'`, or `'plaintext'`.
///
/// Detection logic:
/// 1. Parse Content-Type for known MIME types.
/// 2. Fallback: try to JSON-decode the body.
/// 3. Fallback: check if body looks like XML/HTML.
/// 4. Otherwise return `'plaintext'`.
String detectLanguage(String? contentType, String body) {
  // 1. Content-Type based detection.
  final ct = (contentType ?? '').toLowerCase();
  if (ct.contains('application/json') || ct.contains('text/json')) {
    return 'json';
  }
  if (ct.contains('application/xml') ||
      ct.contains('text/xml') ||
      ct.contains('text/html') ||
      ct.contains('application/xhtml')) {
    return 'xml';
  }
  if (ct.contains('text/plain') ||
      ct.contains('application/x-www-form-urlencoded')) {
    // form-urlencoded is not worth highlighting; treat as plain.
    return 'plaintext';
  }

  // 2. Body-sniffing fallback.
  if (body.trimLeft().startsWith('{') || body.trimLeft().startsWith('[')) {
    try {
      jsonDecode(body);
      return 'json';
    } catch (_) {
      // Not valid JSON, continue checking.
    }
  }

  if (body.trimLeft().startsWith('<')) {
    return 'xml';
  }

  return 'plaintext';
}

/// Pretty-prints a JSON string with 2-space indentation.
///
/// Returns the original [body] if parsing fails.
String prettyPrintJson(String body) {
  try {
    final parsed = jsonDecode(body);
    return const JsonEncoder.withIndent('  ').convert(parsed);
  } catch (_) {
    return body;
  }
}

/// Builds a syntax-highlighted [TextSpan] for the given [body] and [language].
///
/// - [baseStyle] is the fallback text style (font family, size, etc.).
/// - [isDark] selects the highlight theme (GitHub light vs. GitHub dark).
/// - Bodies exceeding [_kMaxHighlightBytes] return a plain [TextSpan].
/// - Unknown languages return a plain [TextSpan].
TextSpan buildHighlightedSpan({
  required String body,
  required String language,
  required TextStyle baseStyle,
  required bool isDark,
}) {
  // Performance guard: skip highlighting for large bodies.
  if (body.length > _kMaxHighlightBytes) {
    return TextSpan(text: body, style: baseStyle);
  }

  // Only json and xml are supported.
  if (language != 'json' && language != 'xml') {
    return TextSpan(text: body, style: baseStyle);
  }

  final theme = isDark ? githubDarkTheme : githubTheme;

  final result = _highlight.highlight(code: body, language: language);
  final renderer = TextSpanRenderer(baseStyle, theme);
  result.render(renderer);

  return renderer.span ?? TextSpan(text: body, style: baseStyle);
}
