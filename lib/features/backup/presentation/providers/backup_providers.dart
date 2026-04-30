/// Riverpod providers for the backup feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../data/datasources/backup_file_datasource.dart';
import '../../data/datasources/backup_hive_reader.dart';
import '../../data/datasources/backup_password_store.dart';
import '../../data/repositories/backup_repository_impl.dart';
import 'backup_notifier.dart';
import 'backup_state.dart';

final backupHiveReaderProvider = Provider<BackupHiveReader>((ref) {
  return BackupHiveReader();
});

final backupFileDataSourceProvider = Provider<BackupFileDataSource>((ref) {
  return BackupFileDataSource();
});

final backupPasswordStoreProvider = Provider<BackupPasswordStore>((ref) {
  return BackupPasswordStore(Hive.box('app_data'));
});

final backupRepositoryProvider = Provider<BackupRepositoryImpl>((ref) {
  return BackupRepositoryImpl(
    ref.watch(backupHiveReaderProvider),
    ref.watch(backupFileDataSourceProvider),
  );
});

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((
  ref,
) {
  return BackupNotifier(
    ref.watch(backupRepositoryProvider),
    ref.watch(backupPasswordStoreProvider),
  );
});

/// Whether encryption is currently enabled.
final isBackupEncryptedProvider = Provider<bool>((ref) {
  return ref.watch(backupPasswordStoreProvider).isEncrypted;
});

/// Whether a backup password has been set.
final hasBackupPasswordProvider = Provider<bool>((ref) {
  return ref.watch(backupPasswordStoreProvider).password != null;
});
