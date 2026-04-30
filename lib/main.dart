import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/platform/app_method_channel.dart';
import 'core/storage/hive_store.dart';
import 'features/check_in/data/datasources/check_in_local_datasource.dart';
import 'features/check_in/data/datasources/check_in_request_log_local_datasource.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await initHive();
  await _migrateCheckInResultCap();

  final container = ProviderContainer();
  AppMethodChannel.init();
  AppMethodChannel.onOpenSettings = () {
    container.read(tabIndexProvider.notifier).state = AppRoutes.settingsTab;
  };

  runApp(UncontrolledProviderScope(container: container, child: const App()));

  FlutterNativeSplash.remove();
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
      CheckInRequestLogLocalDataSource(Hive.box('check_in_request_logs')),
    );
    await ds.migrateResultsToCap();
  } catch (_) {
    // Silent per spec — never block app launch.
  }
}
