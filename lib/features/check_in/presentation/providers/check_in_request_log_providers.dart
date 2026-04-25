/// Riverpod providers for check-in request log feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../dev_tools/request_logger/domain/entities/request_log_entry.dart';
import '../../data/datasources/check_in_request_log_local_datasource.dart';
import '../../data/repositories/check_in_request_log_repository_impl.dart';
import '../../domain/repositories/check_in_request_log_repository.dart';

/// Repository provider for check-in request log persistence.
final checkInRequestLogRepositoryProvider =
    Provider<CheckInRequestLogRepository>((ref) {
  return CheckInRequestLogRepositoryImpl(
    ref.read(checkInRequestLogLocalDataSourceProvider),
  );
});

/// Loads request logs for a specific check-in result.
///
/// Parameterized by the check-in result ID (which equals the correlation ID).
final checkInRequestLogsProvider =
    FutureProvider.family<List<RequestLogEntry>, String>((ref, resultId) async {
  final repo = ref.read(checkInRequestLogRepositoryProvider);
  final result = await repo.getLogsByCorrelationId(resultId);
  return result.when(onSuccess: (logs) => logs, onFailure: (_) => const []);
});

/// Loads ALL persisted request logs, newest first.
final allPersistedRequestLogsProvider =
    FutureProvider<List<RequestLogEntry>>((ref) async {
  return ref.read(checkInRequestLogLocalDataSourceProvider).getAllLogs();
});
