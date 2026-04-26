/// Export formatter for Claude Code configuration.
///
/// Generates a JSON configuration that can be used with Claude Code CLI.
/// Format: `{ "apiUrl": "<base>", "apiKey": "<key>", "model": "<optional>" }`
library;

import 'dart:convert';

import '../../domain/entities/api_key.dart';

/// Exports API keys to Claude Code configuration format.
class ClaudeCodeExporter {
  const ClaudeCodeExporter._();

  /// Exports a single key as Claude Code JSON config.
  ///
  /// Returns a JSON string with `apiUrl`, `apiKey`, and optionally `model`.
  static String exportKey(ApiKey apiKey, String baseUrl) {
    final config = <String, dynamic>{
      'apiUrl': '$baseUrl/v1',
      'apiKey': apiKey.keyValue ?? '',
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  /// Exports multiple keys as an array of Claude Code configs.
  static String exportKeys(List<ApiKey> keys, String baseUrl) {
    final configs = keys
        .where((k) => k.keyValue != null && k.keyValue!.isNotEmpty)
        .map((k) => <String, dynamic>{
              'apiUrl': '$baseUrl/v1',
              'apiKey': k.keyValue!,
              'name': k.name,
            })
        .toList();
    return const JsonEncoder.withIndent('  ').convert(configs);
  }
}
