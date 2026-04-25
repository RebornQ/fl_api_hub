/// Mapper between [RequestLogEntry] and its persistent Map representation.
library;

import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';

/// Serializes / deserializes [RequestLogEntry] for Hive storage.
///
/// The [correlationId] is stored alongside the entry fields so the data
/// source can query by correlation ID without an index.
class RequestLogLogMapper {
  static Map<String, dynamic> toMap(
    RequestLogEntry entry,
    String correlationId,
  ) {
    return {
      'id': entry.id,
      'correlationId': correlationId,
      'startedAt': entry.startedAt.toIso8601String(),
      if (entry.endedAt != null) 'endedAt': entry.endedAt!.toIso8601String(),
      if (entry.elapsed != null) 'elapsedMs': entry.elapsed!.inMilliseconds,
      'method': entry.method,
      'url': entry.url,
      'query': entry.query,
      'requestHeaders': entry.requestHeaders,
      if (entry.requestBody != null) 'requestBody': entry.requestBody,
      if (entry.statusCode != null) 'statusCode': entry.statusCode,
      'responseHeaders': entry.responseHeaders,
      if (entry.responseBody != null) 'responseBody': entry.responseBody,
      if (entry.errorMessage != null) 'errorMessage': entry.errorMessage,
      if (entry.errorType != null) 'errorType': entry.errorType,
    };
  }

  static RequestLogEntry fromMap(Map<String, dynamic> map) {
    return RequestLogEntry(
      id: map['id'] as int,
      correlationId: map['correlationId'] as String?,
      startedAt: DateTime.parse(map['startedAt'] as String),
      endedAt: (map['endedAt'] as String?) != null
          ? DateTime.parse(map['endedAt'] as String)
          : null,
      elapsed: (map['elapsedMs'] as int?) != null
          ? Duration(milliseconds: map['elapsedMs'] as int)
          : null,
      method: map['method'] as String,
      url: map['url'] as String,
      query: Map<String, dynamic>.from(map['query'] as Map),
      requestHeaders: Map<String, String>.from(map['requestHeaders'] as Map),
      requestBody: map['requestBody'] as String?,
      statusCode: map['statusCode'] as int?,
      responseHeaders: Map<String, String>.from(map['responseHeaders'] as Map),
      responseBody: map['responseBody'] as String?,
      errorMessage: map['errorMessage'] as String?,
      errorType: map['errorType'] as String?,
    );
  }
}
