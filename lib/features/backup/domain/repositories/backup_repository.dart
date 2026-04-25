/// Abstract interface for backup/restore operations.
library;

import '../../../../core/result/result.dart';
import '../entities/backup_progress.dart';

/// Contract for backup and restore operations.
abstract class BackupRepository {
  /// Creates a backup file.
  ///
  /// If [password] is provided, the file is AES-256-GCM encrypted.
  /// Otherwise the file is plain JSON.
  /// Returns the path to the created file.
  Future<Result<String>> createBackup({String? password});

  /// Restores data from a backup file.
  ///
  /// [filePath] — path to the backup file.
  /// [password] — required if the file is encrypted; ignored if not.
  /// [replace] — `true` for full replace, `false` for smart merge.
  Future<Result<RestoreSummary>> restoreBackup({
    required String filePath,
    String? password,
    required bool replace,
  });

  /// Streams progress during backup/restore operations.
  Stream<BackupProgress> get progressStream;
}

/// Summary of a restore operation.
class RestoreSummary {
  /// Whether the restore used replace strategy.
  final bool wasReplace;

  /// Number of accounts restored.
  final int accounts;

  /// Number of keys restored.
  final int keys;

  /// Number of tags restored.
  final int tags;

  /// Number of check-in tasks restored.
  final int checkInTasks;

  /// Number of check-in results restored.
  final int checkInResults;

  const RestoreSummary({
    required this.wasReplace,
    required this.accounts,
    required this.keys,
    required this.tags,
    required this.checkInTasks,
    required this.checkInResults,
  });
}
