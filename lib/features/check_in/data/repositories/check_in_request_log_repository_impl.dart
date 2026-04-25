/// Hive-backed implementation of [CheckInRequestLogRepository].
library;

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../data/datasources/check_in_request_log_local_datasource.dart';
import '../../domain/repositories/check_in_request_log_repository.dart';
import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';

class CheckInRequestLogRepositoryImpl implements CheckInRequestLogRepository {
  final CheckInRequestLogLocalDataSource _localDs;

  CheckInRequestLogRepositoryImpl(this._localDs);

  @override
  Future<Result<void>> saveLog(
    String correlationId,
    RequestLogEntry entry,
  ) async {
    try {
      await _localDs.saveLog(correlationId, entry);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(message: e.toString()));
    }
  }

  @override
  Future<Result<List<RequestLogEntry>>> getLogsByCorrelationId(
    String correlationId,
  ) async {
    try {
      return Success(_localDs.getLogsByCorrelationId(correlationId));
    } catch (e) {
      return Failure(StorageException(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteLogsByCorrelationId(String correlationId) async {
    try {
      await _localDs.deleteLogsByCorrelationId(correlationId);
      return const Success(null);
    } catch (e) {
      return Failure(StorageException(message: e.toString()));
    }
  }
}
