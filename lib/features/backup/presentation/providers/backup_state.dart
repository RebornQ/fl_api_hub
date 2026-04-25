/// State machine for backup/restore operations.
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/backup_progress.dart';
import '../../domain/repositories/backup_repository.dart';

/// Sealed state for the backup feature.
sealed class BackupState {
  const BackupState();
}

/// Idle — no operation in progress.
class BackupIdle extends BackupState {
  const BackupIdle();
}

/// Operation in progress with phase and progress info.
class BackupInProgress extends BackupState {
  final BackupProgress progress;
  const BackupInProgress(this.progress);
}

/// Backup created successfully; file is ready for export.
class BackupCreated extends BackupState {
  final String filePath;
  const BackupCreated(this.filePath);
}

/// Restore completed successfully with summary.
class RestoreCompleted extends BackupState {
  final RestoreSummary summary;
  const RestoreCompleted(this.summary);
}

/// Operation failed with an error.
class BackupError extends BackupState {
  final AppException exception;
  const BackupError(this.exception);
}
