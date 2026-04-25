/// Repository interface for check-in request log persistence.
library;

import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';
import '../../../../core/result/result.dart';

/// Abstraction over persistent storage for request logs associated with
/// check-in executions.
abstract class CheckInRequestLogRepository {
  /// Saves a [RequestLogEntry] linked to [correlationId].
  Future<Result<void>> saveLog(String correlationId, RequestLogEntry entry);

  /// Retrieves all request logs for [correlationId].
  Future<Result<List<RequestLogEntry>>> getLogsByCorrelationId(
    String correlationId,
  );

  /// Removes all request logs for [correlationId].
  Future<Result<void>> deleteLogsByCorrelationId(String correlationId);
}
