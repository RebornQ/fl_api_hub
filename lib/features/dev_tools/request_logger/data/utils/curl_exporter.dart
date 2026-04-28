/// Exports a [RequestLogEntry] as a multi-line `curl` command suitable
/// for pasting into a terminal or ticket.
///
/// The exporter redacts sensitive headers during export to ensure credentials
/// (Authorization, Cookie, etc.) are never leaked in the curl output.
/// Users who need the real token should copy it from their own account settings.
library;

import '../../domain/entities/request_log_entry.dart';
import 'header_redactor.dart';

/// Returns a multi-line curl command describing [entry]. The command uses
/// `\` continuations for readability; headers are redacted before export,
/// so the output is safe to share.
///
/// FormData request bodies are omitted with an inline comment since curl
/// cannot reliably reconstruct multipart payloads from a logged summary.
String exportAsCurl(RequestLogEntry entry) {
  final buf = StringBuffer('curl');

  final method = entry.method.toUpperCase();
  if (method != 'GET') {
    buf.write(' -X $method');
  }

  // URL already contains the query string (see interceptor where we use
  // `options.uri.toString()`), so no further assembly is required.
  buf.write(" \\\n  '${_escapeSingleQuote(entry.url)}'");

  // Redact sensitive headers before export for security.
  final redactedHeaders = redactHeaders(entry.requestHeaders);
  redactedHeaders.forEach((name, value) {
    buf.write(" \\\n  -H '${_escapeSingleQuote('$name: $value')}'");
  });

  final body = entry.requestBody;
  if (body != null && body.isNotEmpty) {
    if (body.startsWith('<FormData')) {
      buf.write(' \\\n  # FormData 不支持导出');
    } else {
      buf.write(" \\\n  --data-raw '${_escapeSingleQuote(body)}'");
    }
  }

  return buf.toString();
}

/// Escapes a single-quoted shell string by splicing: `foo'bar` becomes
/// `foo'\''bar` so the value can be safely embedded in `'…'`.
String _escapeSingleQuote(String input) => input.replaceAll("'", r"'\''");
