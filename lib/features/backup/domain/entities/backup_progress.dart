/// Phase and progress tracking for backup/restore operations.
library;

/// Phases of a backup or restore operation.
enum BackupPhase {
  readingData('正在读取数据…'),
  buildingBackup('正在构建备份…'),
  computingChecksum('正在计算校验和…'),
  encrypting('正在加密…'),
  writingFile('正在写入文件…'),
  decrypting('正在解密…'),
  verifyingChecksum('正在验证完整性…'),
  parsingData('正在解析数据…'),
  resolvingConflicts('正在解决冲突…'),
  writingToStorage('正在写入存储…'),
  done('完成');

  final String label;
  const BackupPhase(this.label);
}

/// Progress snapshot for a backup/restore operation.
class BackupProgress {
  final BackupPhase phase;
  final double progress; // 0.0 to 1.0

  const BackupProgress({required this.phase, required this.progress});
}
