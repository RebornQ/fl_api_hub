/// Metadata header for a backup file.
///
/// Stored as the outer envelope of the backup JSON. The [checksum] is a
/// SHA-256 hex digest of the serialized `data` field, computed *before*
/// encryption.
library;

/// Backup file metadata.
class BackupMetadata {
  /// Format version.
  ///
  /// - `1` (legacy): seven Hive boxes — `accounts`, `keys`, `tags`,
  ///   `check_in_tasks`, `check_in_results`, `scheduler_config`,
  ///   `app_data`.
  /// - `2` (current): adds the `network_proxy` singleton box and exposes
  ///   it as the top-level `global_proxy` field. Account entities also
  ///   gain `proxyMode` + `proxyConfig`. Older v1 backups still load
  ///   because every new field defaults to a no-op value when missing.
  final int version;

  /// Whether the payload is AES-256-GCM encrypted.
  final bool encrypted;

  /// When the backup was created.
  final DateTime timestamp;

  /// App version that created the backup.
  final String appVersion;

  /// SHA-256 hex digest of the JSON-serialized `data` field.
  final String checksum;

  const BackupMetadata({
    required this.version,
    required this.encrypted,
    required this.timestamp,
    required this.appVersion,
    required this.checksum,
  });

  Map<String, dynamic> toMap() => {
    'version': version,
    'encrypted': encrypted,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'app_version': appVersion,
    'checksum': checksum,
  };

  static BackupMetadata fromMap(Map<String, dynamic> map) => BackupMetadata(
    version: map['version'] as int? ?? 1,
    encrypted: map['encrypted'] as bool? ?? false,
    timestamp: map['timestamp'] is String
        ? DateTime.parse(map['timestamp'] as String)
        : DateTime.now(),
    appVersion: map['app_version'] as String? ?? '0.0.0',
    checksum: map['checksum'] as String? ?? '',
  );
}
