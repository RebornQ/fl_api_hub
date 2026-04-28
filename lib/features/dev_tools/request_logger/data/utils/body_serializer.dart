/// Body serialization utilities for the request logger.
///
/// The logger must convert Dio's request/response bodies (which can be any
/// `Object?`) into a safe string suitable for storage in the in-memory ring
/// buffer.
///
/// Rules:
/// - `null` → `null` (nothing to record).
/// - `FormData` → a summary string `<FormData: fields=N, files=M>` (the
///   attached file streams are never read so large uploads stay cheap).
/// - `String` → passed through unchanged.
/// - `Map` / `List` → `jsonEncode` snapshot.
/// - Non-text responses (Content-Type outside JSON/text) → binary
///   placeholder `<二进制数据, X bytes>`.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

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

  return text;
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

  return text;
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
