/// Body serialization & truncation utilities for the request logger.
///
/// The logger must convert Dio's request/response bodies (which can be any
/// `Object?`) into a safe, bounded string suitable for storage in the
/// in-memory ring buffer.
///
/// Rules:
/// - `null` → `null` (nothing to record).
/// - `FormData` → a summary string `<FormData: fields=N, files=M>` (the
///   attached file streams are never read so large uploads stay cheap).
/// - `String` → passed through, then UTF-8-length-checked for truncation.
/// - `Map` / `List` → `jsonEncode` snapshot.
/// - Non-text responses (Content-Type outside JSON/text) → binary
///   placeholder `<二进制数据, X bytes>`.
///
/// Truncation threshold is 64 KB of UTF-8-encoded bytes (see
/// [kMaxBodyBytes]); oversized bodies are sliced and suffixed with the
/// original size so the user can tell by how much the snapshot was cut.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

/// Maximum UTF-8 byte length retained for a single request / response body.
const int kMaxBodyBytes = 64 * 1024;

/// Serializes a Dio request body (`options.data`) to a storable string.
///
/// Returns `null` for a `null` input, matching the "no body" case.
String? serializeRequestBody(Object? data) {
  if (data == null) return null;

  if (data is FormData) {
    return '<FormData: fields=${data.fields.length}, files=${data.files.length}>';
  }

  String text;
  if (data is String) {
    text = data;
  } else if (data is Map || data is List) {
    text = _safeJsonEncode(data);
  } else {
    text = data.toString();
  }

  return _truncateUtf8(text);
}

/// Serializes a Dio response body (`response.data`) to a storable string.
///
/// When [contentType] is provided and does **not** indicate text-like
/// content (`application/json*`, `text/*`), the raw body is replaced with
/// a placeholder describing its size. Unknown / missing [contentType] is
/// treated as text because Dio defaults to JSON for this project.
String? serializeResponseBody(Object? data, {String? contentType}) {
  if (data == null) return null;

  final normalizedType = (contentType ?? '').toLowerCase();
  final isTextLike =
      normalizedType.isEmpty ||
      normalizedType.startsWith('application/json') ||
      normalizedType.startsWith('application/xml') ||
      normalizedType.startsWith('application/x-www-form-urlencoded') ||
      normalizedType.startsWith('text/');

  if (!isTextLike) {
    return '<二进制数据, ${_estimateSize(data)} bytes>';
  }

  String text;
  if (data is String) {
    text = data;
  } else if (data is List<int>) {
    try {
      text = utf8.decode(data);
    } catch (_) {
      return '<二进制数据, ${data.length} bytes>';
    }
  } else if (data is Map || data is List) {
    text = _safeJsonEncode(data);
  } else {
    text = data.toString();
  }

  return _truncateUtf8(text);
}

String _safeJsonEncode(Object? data) {
  try {
    return jsonEncode(data);
  } catch (_) {
    return data.toString();
  }
}

int _estimateSize(Object data) {
  if (data is List<int>) return data.length;
  if (data is String) return utf8.encode(data).length;
  return data.toString().length;
}

/// Returns [text] unchanged when its UTF-8 byte length is within the
/// allowed budget; otherwise slices at the byte boundary and appends a
/// suffix declaring the original size in whole kilobytes.
String _truncateUtf8(String text) {
  final bytes = utf8.encode(text);
  if (bytes.length <= kMaxBodyBytes) return text;

  final kb = (bytes.length / 1024).round();
  final sliced = utf8.decode(
    bytes.sublist(0, kMaxBodyBytes),
    allowMalformed: true,
  );
  return '$sliced\n...（已截断，原始 $kb KB）';
}
