/// Export formatter for Cherry Studio configuration.
///
/// Generates a JSON configuration compatible with Cherry Studio's
/// OpenAI-compatible provider format.
library;

import 'dart:convert';

import '../../domain/entities/api_key.dart';

/// Exports API keys to Cherry Studio provider configuration format.
class CherryStudioExporter {
  const CherryStudioExporter._();

  /// Exports a single key as a Cherry Studio provider config.
  ///
  /// Format follows Cherry Studio's "Add Provider" schema:
  /// `{ "name": "<provider>", "apiUrl": "<base>/v1", "apiKey": "<key>" }`
  static String exportKey(ApiKey apiKey, String baseUrl, {String? providerName}) {
    final config = <String, dynamic>{
      'name': providerName ?? apiKey.name,
      'apiUrl': '$baseUrl/v1',
      'apiKey': apiKey.keyValue ?? '',
    };
    return const JsonEncoder.withIndent('  ').convert(config);
  }

  /// Exports multiple keys as Cherry Studio provider configs.
  static String exportKeys(
    List<ApiKey> keys,
    String baseUrl, {
    String? providerName,
  }) {
    final configs = keys
        .where((k) => k.keyValue != null && k.keyValue!.isNotEmpty)
        .map((k) => <String, dynamic>{
              'name': providerName ?? k.name,
              'apiUrl': '$baseUrl/v1',
              'apiKey': k.keyValue!,
            })
        .toList();
    return const JsonEncoder.withIndent('  ').convert(configs);
  }
}
