/// Riverpod providers for the Check-in feature.
///
/// Wires [CheckInRepositoryImpl] to its dependencies and exposes:
/// - [checkInProvider] for task list management.
/// - [latestCheckInResultProvider] for the most recent result per task.
/// - [checkInResultsProvider] for the full result history per task.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../data/datasources/check_in_local_datasource.dart';
import '../../data/repositories/check_in_repository_impl.dart';
import '../../domain/entities/check_in_result.dart';
import '../../domain/entities/check_in_task.dart';
import '../../domain/repositories/check_in_repository.dart';
import 'check_in_notifier.dart';

export 'check_in_notifier.dart';

/// Provides the [CheckInRepository] implementation.
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepositoryImpl(ref.watch(checkInLocalDataSourceProvider));
});

/// Manages the list of [CheckInTask] entities.
///
/// UI code should watch this provider to display the task list.
/// Use the notifier methods for CRUD and manual check-in execution.
final checkInProvider =
    AsyncNotifierProvider<CheckInNotifier, List<CheckInTask>>(
      CheckInNotifier.new,
    );

/// Read-only provider for the latest [CheckInResult] of a task.
///
/// Returns `null` if the task has never been executed.
final latestCheckInResultProvider =
    FutureProvider.family<CheckInResult?, String>((ref, taskId) async {
      final repo = ref.watch(checkInRepositoryProvider);
      final result = await repo.getLatestResult(taskId);
      return result.dataOrNull;
    });

/// Read-only provider for all [CheckInResult]s of a task, newest first.
final checkInResultsProvider =
    FutureProvider.family<List<CheckInResult>, String>((ref, taskId) async {
      final repo = ref.watch(checkInRepositoryProvider);
      final result = await repo.getResultsByTaskId(taskId);
      return result.dataOrNull ?? [];
    });
