/// AsyncNotifier that manages backup/restore state and orchestrates operations.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../data/datasources/backup_password_store.dart';
import '../../domain/entities/backup_progress.dart';
import '../../domain/repositories/backup_repository.dart';
import 'backup_state.dart';

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupRepository _repository;
  final BackupPasswordStore _passwordStore;
  StreamSubscription<BackupProgress>? _progressSub;

  BackupNotifier(this._repository, this._passwordStore)
    : super(const BackupIdle());

  /// Creates a backup using the stored password (if any).
  Future<void> createBackup() async {
    state = const BackupInProgress(
      BackupProgress(phase: BackupPhase.readingData, progress: 0),
    );
    _listenProgress();

    final password = _passwordStore.isEncrypted
        ? _passwordStore.password
        : null;

    final result = await _repository.createBackup(password: password);

    if (!mounted) return;

    state = result.when(
      onSuccess: (filePath) => BackupCreated(filePath),
      onFailure: (e) => BackupError(e),
    );
  }

  /// Restores from a backup file.
  Future<void> restoreBackup({
    required String filePath,
    String? password,
    required bool replace,
  }) async {
    state = const BackupInProgress(
      BackupProgress(phase: BackupPhase.decrypting, progress: 0),
    );
    _listenProgress();

    final result = await _repository.restoreBackup(
      filePath: filePath,
      password: password,
      replace: replace,
    );

    if (!mounted) return;

    state = result.when(
      onSuccess: (summary) => RestoreCompleted(summary),
      onFailure: (e) => BackupError(e),
    );
  }

  /// Resets state to idle.
  void reset() {
    state = const BackupIdle();
  }

  void _listenProgress() {
    _progressSub?.cancel();
    _progressSub = _repository.progressStream.listen((progress) {
      if (mounted) {
        state = BackupInProgress(progress);
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
