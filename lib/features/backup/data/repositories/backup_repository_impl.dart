/// Coordinates backup creation and restoration.
///
/// Orchestrates [BackupHiveReader], [BackupCodec], [BackupFileDataSource],
/// and [BackupPasswordStore] to provide a unified backup/restore API.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/backup_progress.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_file_datasource.dart';
import '../datasources/backup_hive_reader.dart';
import '../models/backup_codec.dart';
import '../models/backup_data.dart';
import '../models/backup_metadata.dart';
import '../models/merge_strategy.dart';

class BackupRepositoryImpl implements BackupRepository {
  final BackupHiveReader _hiveReader;
  final BackupFileDataSource _fileDataSource;

  final _progressController = StreamController<BackupProgress>.broadcast();

  BackupRepositoryImpl(this._hiveReader, this._fileDataSource);

  @override
  Stream<BackupProgress> get progressStream => _progressController.stream;

  @override
  Future<Result<String>> createBackup({String? password}) async {
    try {
      // Phase 1: Read data from Hive.
      _emit(BackupPhase.readingData, 0.1);
      final data = _hiveReader.readAll();

      // Phases 2–4: JSON serialization + optional encryption in isolate.
      _emit(BackupPhase.buildingBackup, 0.3);
      final bytes = await Isolate.run(() {
        final dataMap = data.toMap();
        final dataJson = jsonEncode(dataMap);
        final checksum = BackupCodec.computeChecksum(dataJson);

        final metadata = BackupMetadata(
          // v2 introduces the `global_proxy` top-level field. Older v1
          // backups still load fine — `BackupData.fromMap` falls back to
          // an empty map when the field is missing.
          version: 2,
          encrypted: password != null,
          timestamp: DateTime.now(),
          appVersion: '1.0.0',
          // TODO: read from package_info
          checksum: checksum,
        );
        final envelope = {...metadata.toMap(), 'data': dataMap};
        final envelopeJson = jsonEncode(envelope);

        if (password != null) {
          return BackupCodec.encrypt(envelopeJson, password);
        }
        return Uint8List.fromList(utf8.encode(envelopeJson));
      });

      // Phase 5: Write to temp file.
      _emit(BackupPhase.writingFile, 0.8);
      final filename = 'fl_api_hub_backup_${_timestampSuffix()}.flhbkp';
      final filePath = await _fileDataSource.writeToTempFile(bytes, filename);

      _emit(BackupPhase.done, 1.0);
      return Success(filePath);
    } on AppException {
      rethrow;
    } catch (e, st) {
      return Failure(
        BackupException(message: '创建备份失败：$e', originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<RestoreSummary>> restoreBackup({
    required String filePath,
    String? password,
    required bool replace,
  }) async {
    try {
      // Phase 1: Read file.
      _emit(BackupPhase.decrypting, 0.05);
      final bytes = await _fileDataSource.readFile(filePath);

      // Phase 2: Decrypt if needed.
      _emit(BackupPhase.decrypting, 0.15);
      final String envelopeJson;
      if (BackupCodec.isJson(bytes)) {
        envelopeJson = utf8.decode(bytes);
      } else {
        if (password == null || password.isEmpty) {
          return const Failure(BackupException(message: '备份文件已加密，请输入密码'));
        }
        try {
          envelopeJson = await Isolate.run(
            () => BackupCodec.decrypt(bytes, password),
          );
        } on FormatException {
          return const Failure(BackupException(message: '密码错误，无法解密备份文件'));
        }
      }

      // Phase 3: Parse JSON.
      _emit(BackupPhase.parsingData, 0.3);
      final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
      final metadata = BackupMetadata.fromMap(envelope);

      // Phase 4: Verify checksum.
      _emit(BackupPhase.verifyingChecksum, 0.4);
      final dataJson = jsonEncode(envelope['data']);
      final computedChecksum = BackupCodec.computeChecksum(dataJson);
      if (computedChecksum != metadata.checksum) {
        return const Failure(BackupException(message: '备份文件校验和不匹配，文件可能已损坏'));
      }

      // Phase 5: Parse data.
      _emit(BackupPhase.parsingData, 0.5);
      final backupData = BackupData.fromMap(
        envelope['data'] as Map<String, dynamic>,
      );

      // Phase 6: Write to storage.
      if (replace) {
        _emit(BackupPhase.writingToStorage, 0.7);
        await _hiveReader.writeAll(backupData);
      } else {
        _emit(BackupPhase.resolvingConflicts, 0.6);
        final localData = _hiveReader.readAll();
        final (resolved: resolved, result: _) = resolveMerge(
          localData,
          backupData,
        );
        _emit(BackupPhase.writingToStorage, 0.7);
        await _hiveReader.writeData(resolved);
      }

      _emit(BackupPhase.done, 1.0);

      return Success(
        RestoreSummary(
          wasReplace: replace,
          accounts: backupData.accounts.length,
          keys: backupData.keys.length,
          tags: backupData.tags.length,
          checkInTasks: backupData.checkInTasks.length,
          checkInResults: backupData.checkInResults.length,
        ),
      );
    } on BackupException {
      rethrow;
    } on AppException {
      rethrow;
    } catch (e, st) {
      return Failure(
        BackupException(message: '恢复备份失败：$e', originalError: e, stackTrace: st),
      );
    }
  }

  void _emit(BackupPhase phase, double progress) {
    if (!_progressController.isClosed) {
      _progressController.add(BackupProgress(phase: phase, progress: progress));
    }
  }

  String _timestampSuffix() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
