/// Merge strategy for restoring backup data.
///
/// Handles conflict resolution when backup data overlaps with existing data.
library;

import '../models/backup_data.dart';

/// Restore mode chosen by the user.
enum RestoreMode {
  /// Clear all existing data, then write backup data.
  replace,

  /// Intelligently merge backup data with existing data.
  merge,
}

/// Result of a merge operation with per-entity counts.
class MergeResult {
  final int accountsInserted;
  final int accountsUpdated;
  final int keysInserted;
  final int keysSkipped;
  final int tagsInserted;
  final int tagsUpdated;
  final int tagsConflicted;
  final int tasksInserted;
  final int tasksSkipped;
  final int resultsInserted;
  final int resultsSkipped;
  final bool schedulerUpdated;

  const MergeResult({
    required this.accountsInserted,
    required this.accountsUpdated,
    required this.keysInserted,
    required this.keysSkipped,
    required this.tagsInserted,
    required this.tagsUpdated,
    required this.tagsConflicted,
    required this.tasksInserted,
    required this.tasksSkipped,
    required this.resultsInserted,
    required this.resultsSkipped,
    required this.schedulerUpdated,
  });
}

/// Resolves merge of local and incoming backup data.
///
/// Returns resolved [BackupData] and a [MergeResult] with statistics.
({BackupData resolved, MergeResult result}) resolveMerge(
  BackupData local,
  BackupData incoming,
) {
  // 1. Tags: merge by ID, handle synonym conflicts.
  final mergedTags = <String, Map<String, dynamic>>{};
  for (final tag in local.tags) {
    mergedTags[tag['id'] as String] = tag;
  }
  var tagsInserted = 0;
  var tagsUpdated = 0;
  var tagsConflicted = 0;
  final localTagNames = {
    for (final t in local.tags)
      (t['name'] as String).toLowerCase(): t['id'] as String,
  };

  for (final tag in incoming.tags) {
    final id = tag['id'] as String;
    if (mergedTags.containsKey(id)) {
      // Same ID — keep the one with newer updatedAt.
      if (_isNewer(tag, mergedTags[id]!)) {
        mergedTags[id] = tag;
        tagsUpdated++;
      }
    } else {
      final name = (tag['name'] as String).toLowerCase();
      if (localTagNames.containsKey(name)) {
        // Synonym conflict — rename incoming tag.
        final renamed = Map<String, dynamic>.from(tag);
        renamed['name'] = '${tag['name']} (备份)';
        mergedTags[id] = renamed;
        tagsConflicted++;
      } else {
        mergedTags[id] = tag;
        tagsInserted++;
      }
    }
  }

  // 2. Accounts: merge by ID.
  final mergedAccounts = <String, Map<String, dynamic>>{};
  for (final a in local.accounts) {
    mergedAccounts[a['id'] as String] = a;
  }
  var accountsInserted = 0;
  var accountsUpdated = 0;

  for (final account in incoming.accounts) {
    final id = account['id'] as String;
    if (mergedAccounts.containsKey(id)) {
      if (_isNewer(account, mergedAccounts[id]!)) {
        // Merge tagIds: union of both sets.
        final localTags = List<String>.from(
          mergedAccounts[id]!['tagIds'] as List? ?? [],
        );
        final incomingTags = List<String>.from(
          account['tagIds'] as List? ?? [],
        );
        final mergedTagIdList = <String>[
          ...localTags,
          ...incomingTags.where((t) => !localTags.contains(t)),
        ];
        final updated = Map<String, dynamic>.from(account);
        updated['tagIds'] = mergedTagIdList;
        mergedAccounts[id] = updated;
        accountsUpdated++;
      }
    } else {
      mergedAccounts[id] = account;
      accountsInserted++;
    }
  }
  final mergedAccountIds = mergedAccounts.keys.toSet();

  // 3. Keys: insert if parent account exists, skip orphans.
  final mergedKeys = <String, Map<String, dynamic>>{};
  for (final k in local.keys) {
    mergedKeys[k['id'] as String] = k;
  }
  var keysInserted = 0;
  var keysSkipped = 0;

  for (final key in incoming.keys) {
    final id = key['id'] as String;
    final accountId = key['accountId'] as String?;
    if (mergedKeys.containsKey(id)) {
      if (_isNewer(key, mergedKeys[id]!)) {
        mergedKeys[id] = key;
      }
    } else if (accountId != null && mergedAccountIds.contains(accountId)) {
      mergedKeys[id] = key;
      keysInserted++;
    } else {
      keysSkipped++;
    }
  }

  // 4. Check-in tasks: insert if parent account exists.
  final mergedTasks = <String, Map<String, dynamic>>{};
  for (final t in local.checkInTasks) {
    mergedTasks[t['id'] as String] = t;
  }
  var tasksInserted = 0;
  var tasksSkipped = 0;

  for (final task in incoming.checkInTasks) {
    final id = task['id'] as String;
    final accountId = task['accountId'] as String?;
    if (mergedTasks.containsKey(id)) {
      if (_isNewer(task, mergedTasks[id]!)) {
        mergedTasks[id] = task;
      }
    } else if (accountId != null && mergedAccountIds.contains(accountId)) {
      mergedTasks[id] = task;
      tasksInserted++;
    } else {
      tasksSkipped++;
    }
  }
  final mergedTaskIds = mergedTasks.keys.toSet();

  // 5. Check-in results: insert if parent task AND account exist.
  final mergedResults = <String, Map<String, dynamic>>{};
  for (final r in local.checkInResults) {
    mergedResults[r['id'] as String] = r;
  }
  var resultsInserted = 0;
  var resultsSkipped = 0;

  for (final result in incoming.checkInResults) {
    final id = result['id'] as String;
    if (mergedResults.containsKey(id)) {
      // Results are immutable — keep existing.
      continue;
    }
    final taskId = result['taskId'] as String?;
    final accountId = result['accountId'] as String?;
    if (taskId != null &&
        mergedTaskIds.contains(taskId) &&
        accountId != null &&
        mergedAccountIds.contains(accountId)) {
      mergedResults[id] = result;
      resultsInserted++;
    } else {
      resultsSkipped++;
    }
  }

  // 6. Scheduler config: keep incoming if it has enabled=true.
  final mergedScheduler = Map<String, dynamic>.from(local.schedulerConfig);
  var schedulerUpdated = false;
  if (incoming.schedulerConfig['enabled'] == true) {
    mergedScheduler
      ..clear()
      ..addAll(incoming.schedulerConfig);
    schedulerUpdated = true;
  }

  // 7. App data: merge by key (backup wins for non-theme keys).
  final mergedAppData = Map<String, dynamic>.from(local.appData);
  mergedAppData.addAll(incoming.appData);

  return (
    resolved: BackupData(
      accounts: mergedAccounts.values.toList(),
      keys: mergedKeys.values.toList(),
      tags: mergedTags.values.toList(),
      checkInTasks: mergedTasks.values.toList(),
      checkInResults: mergedResults.values.toList(),
      schedulerConfig: mergedScheduler,
      appData: mergedAppData,
    ),
    result: MergeResult(
      accountsInserted: accountsInserted,
      accountsUpdated: accountsUpdated,
      keysInserted: keysInserted,
      keysSkipped: keysSkipped,
      tagsInserted: tagsInserted,
      tagsUpdated: tagsUpdated,
      tagsConflicted: tagsConflicted,
      tasksInserted: tasksInserted,
      tasksSkipped: tasksSkipped,
      resultsInserted: resultsInserted,
      resultsSkipped: resultsSkipped,
      schedulerUpdated: schedulerUpdated,
    ),
  );
}

/// Returns `true` if [a] has a newer `updatedAt` than [b].
bool _isNewer(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aTime = a['updatedAt'] as String?;
  final bTime = b['updatedAt'] as String?;
  if (aTime == null || bTime == null) return true;
  return aTime.compareTo(bTime) > 0;
}
