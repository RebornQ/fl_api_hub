/// Raw backup payload — stores entity maps from 7 Hive boxes.
///
/// Each field holds the same `Map<String, dynamic>` values that existing
/// mappers produce via `toMap()`. On restore, `fromMap()` is called to
/// reconstruct typed entities. This decouples the backup format from entity
/// constructors and provides forward compatibility.
library;

/// Backup payload containing raw maps from all backed-up Hive boxes.
class BackupData {
  /// Account entity maps.
  final List<Map<String, dynamic>> accounts;

  /// API key entity maps.
  final List<Map<String, dynamic>> keys;

  /// Tag entity maps.
  final List<Map<String, dynamic>> tags;

  /// Check-in task entity maps.
  final List<Map<String, dynamic>> checkInTasks;

  /// Check-in result entity maps.
  final List<Map<String, dynamic>> checkInResults;

  /// Scheduler config (singleton document).
  final Map<String, dynamic> schedulerConfig;

  /// General app data key-value pairs.
  final Map<String, dynamic> appData;

  const BackupData({
    required this.accounts,
    required this.keys,
    required this.tags,
    required this.checkInTasks,
    required this.checkInResults,
    required this.schedulerConfig,
    required this.appData,
  });

  Map<String, dynamic> toMap() => {
    'accounts': accounts,
    'keys': keys,
    'tags': tags,
    'check_in_tasks': checkInTasks,
    'check_in_results': checkInResults,
    'scheduler_config': schedulerConfig,
    'app_data': appData,
  };

  static BackupData fromMap(Map<String, dynamic> map) => BackupData(
    accounts: _listOfMaps(map['accounts']),
    keys: _listOfMaps(map['keys']),
    tags: _listOfMaps(map['tags']),
    checkInTasks: _listOfMaps(map['check_in_tasks']),
    checkInResults: _listOfMaps(map['check_in_results']),
    schedulerConfig: Map<String, dynamic>.from(
      map['scheduler_config'] as Map? ?? {},
    ),
    appData: Map<String, dynamic>.from(map['app_data'] as Map? ?? {}),
  );
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
