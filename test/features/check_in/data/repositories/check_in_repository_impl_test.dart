import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/error/app_exception.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';
import 'package:all_api_hub_flutter/features/check_in/data/datasources/check_in_local_datasource.dart';
import 'package:all_api_hub_flutter/features/check_in/data/repositories/check_in_repository_impl.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_result.dart';
import 'package:all_api_hub_flutter/features/check_in/domain/entities/check_in_task.dart';

class MockCheckInLocalDataSource extends Mock
    implements CheckInLocalDataSource {}

void main() {
  late MockCheckInLocalDataSource mockLocal;
  late CheckInRepositoryImpl repository;

  final testTask = CheckInTask(
    id: 'task-id',
    accountId: 'account-id',
    enabled: true,
    scheduleTime: '08:00',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testResult = CheckInResult(
    id: 'result-id',
    taskId: 'task-id',
    accountId: 'account-id',
    status: CheckInStatus.success,
    message: 'Check-in successful',
    rewardAmount: 10.0,
    executedAt: DateTime(2026, 1, 1, 8, 0),
  );

  setUpAll(() {
    registerFallbackValue(testTask);
    registerFallbackValue(testResult);
  });

  setUp(() {
    mockLocal = MockCheckInLocalDataSource();
    repository = CheckInRepositoryImpl(mockLocal);
  });

  group('CheckInRepositoryImpl', () {
    // ── Task operations ──────────────────────────────────────────────

    group('getAllTasks', () {
      test('returns Success with task list', () async {
        when(() => mockLocal.getAllTasks()).thenReturn([testTask]);

        final result = await repository.getAllTasks();

        expect(result, isA<Success<List<CheckInTask>>>());
        expect((result as Success<List<CheckInTask>>).data, [testTask]);
        verify(() => mockLocal.getAllTasks()).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.getAllTasks()).thenThrow(Exception('db error'));

        final result = await repository.getAllTasks();

        expect(result, isA<Failure<List<CheckInTask>>>());
        expect(
          (result as Failure<List<CheckInTask>>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getTasksByAccountId', () {
      test('returns Success with filtered task list', () async {
        when(
          () => mockLocal.getTasksByAccountId('account-id'),
        ).thenReturn([testTask]);

        final result = await repository.getTasksByAccountId('account-id');

        expect(result, isA<Success<List<CheckInTask>>>());
        expect((result as Success<List<CheckInTask>>).data, [testTask]);
        verify(() => mockLocal.getTasksByAccountId('account-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getTasksByAccountId('account-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getTasksByAccountId('account-id');

        expect(result, isA<Failure<List<CheckInTask>>>());
        expect(
          (result as Failure<List<CheckInTask>>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getTaskById', () {
      test('returns Success when task is found', () async {
        when(() => mockLocal.getTaskById('task-id')).thenReturn(testTask);

        final result = await repository.getTaskById('task-id');

        expect(result, isA<Success<CheckInTask>>());
        expect((result as Success<CheckInTask>).data, testTask);
        verify(() => mockLocal.getTaskById('task-id')).called(1);
      });

      test('returns Failure with task not found when null', () async {
        when(() => mockLocal.getTaskById('missing-id')).thenReturn(null);

        final result = await repository.getTaskById('missing-id');

        expect(result, isA<Failure<CheckInTask>>());
        final failure = result as Failure<CheckInTask>;
        expect(failure.exception, isA<StorageException>());
        expect(failure.exception.message, contains('Check-in task not found'));
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getTaskById('task-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getTaskById('task-id');

        expect(result, isA<Failure<CheckInTask>>());
        expect(
          (result as Failure<CheckInTask>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('saveTask', () {
      test('returns Success with saved task', () async {
        when(() => mockLocal.saveTask(any())).thenAnswer((_) async {});

        final result = await repository.saveTask(testTask);

        expect(result, isA<Success<CheckInTask>>());
        expect((result as Success<CheckInTask>).data, testTask);
        verify(() => mockLocal.saveTask(testTask)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.saveTask(any()),
        ).thenThrow(Exception('save failed'));

        final result = await repository.saveTask(testTask);

        expect(result, isA<Failure<CheckInTask>>());
        expect(
          (result as Failure<CheckInTask>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('deleteTask', () {
      test('returns Success with null', () async {
        when(() => mockLocal.deleteTask('task-id')).thenAnswer((_) async {});

        final result = await repository.deleteTask('task-id');

        expect(result, isA<Success<void>>());
        verify(() => mockLocal.deleteTask('task-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.deleteTask('task-id'),
        ).thenThrow(Exception('delete failed'));

        final result = await repository.deleteTask('task-id');

        expect(result, isA<Failure<void>>());
        expect((result as Failure<void>).exception, isA<StorageException>());
      });
    });

    // ── Result operations ────────────────────────────────────────────

    group('getLatestResult', () {
      test('returns Success with latest result', () async {
        when(() => mockLocal.getLatestResult('task-id')).thenReturn(testResult);

        final result = await repository.getLatestResult('task-id');

        expect(result, isA<Success<CheckInResult?>>());
        expect((result as Success<CheckInResult?>).data, testResult);
        verify(() => mockLocal.getLatestResult('task-id')).called(1);
      });

      test('returns Success with null when no results', () async {
        when(() => mockLocal.getLatestResult('task-id')).thenReturn(null);

        final result = await repository.getLatestResult('task-id');

        expect(result, isA<Success<CheckInResult?>>());
        expect((result as Success<CheckInResult?>).data, isNull);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getLatestResult('task-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getLatestResult('task-id');

        expect(result, isA<Failure<CheckInResult?>>());
        expect(
          (result as Failure<CheckInResult?>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('saveResult', () {
      test('returns Success with saved result', () async {
        when(() => mockLocal.saveResult(any())).thenAnswer((_) async {});

        final result = await repository.saveResult(testResult);

        expect(result, isA<Success<CheckInResult>>());
        expect((result as Success<CheckInResult>).data, testResult);
        verify(() => mockLocal.saveResult(testResult)).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.saveResult(any()),
        ).thenThrow(Exception('save failed'));

        final result = await repository.saveResult(testResult);

        expect(result, isA<Failure<CheckInResult>>());
        expect(
          (result as Failure<CheckInResult>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getResultsByTaskId', () {
      test('returns Success with result list', () async {
        when(
          () => mockLocal.getResultsByTaskId('task-id'),
        ).thenReturn([testResult]);

        final result = await repository.getResultsByTaskId('task-id');

        expect(result, isA<Success<List<CheckInResult>>>());
        expect((result as Success<List<CheckInResult>>).data, [testResult]);
        verify(() => mockLocal.getResultsByTaskId('task-id')).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(
          () => mockLocal.getResultsByTaskId('task-id'),
        ).thenThrow(Exception('db error'));

        final result = await repository.getResultsByTaskId('task-id');

        expect(result, isA<Failure<List<CheckInResult>>>());
        expect(
          (result as Failure<List<CheckInResult>>).exception,
          isA<StorageException>(),
        );
      });
    });

    group('getAllResults', () {
      test('returns Success with all results', () async {
        when(() => mockLocal.getAllResults()).thenReturn([testResult]);

        final result = await repository.getAllResults();

        expect(result, isA<Success<List<CheckInResult>>>());
        expect((result as Success<List<CheckInResult>>).data, [testResult]);
        verify(() => mockLocal.getAllResults()).called(1);
      });

      test('returns Failure with StorageException on error', () async {
        when(() => mockLocal.getAllResults()).thenThrow(Exception('db error'));

        final result = await repository.getAllResults();

        expect(result, isA<Failure<List<CheckInResult>>>());
        expect(
          (result as Failure<List<CheckInResult>>).exception,
          isA<StorageException>(),
        );
      });
    });
  });
}
