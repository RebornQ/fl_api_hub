import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/storage/hive_store.dart';
import 'features/check_in/data/datasources/check_in_local_datasource.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHive();
  await _migrateCheckInResultCap();
  runApp(const App());
}

/// Silently trims per-account check-in results down to
/// [kCheckInResultsCapPerAccount] on startup.
///
/// Intended as a one-shot migration for existing users whose
/// `check_in_results` box was populated before the per-account cap was
/// enforced. Runs synchronously before `runApp` so the first UI read sees
/// a tidy box. Any failure is swallowed to avoid blocking app launch.
Future<void> _migrateCheckInResultCap() async {
  try {
    final ds = CheckInLocalDataSource(
      Hive.box('check_in_tasks'),
      Hive.box('check_in_results'),
    );
    await ds.migrateResultsToCap();
  } catch (_) {
    // Silent per spec — never block app launch.
  }
}
