/// Riverpod providers for the check-in scheduler subsystem.
///
/// Wires [ForegroundScheduler], [SchedulerConfig], and
/// [CheckInSchedulerService] together. UI code should watch
/// [schedulerConfigProvider] for config state and
/// [checkInSchedulerStatusProvider] for scheduler activity status.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/scheduler/check_in_scheduler_service.dart';
import '../../../../core/scheduler/foreground_scheduler.dart';
import '../../domain/entities/scheduler_config.dart';
import 'scheduler_config_notifier.dart';

// ── Foreground scheduler ──────────────────────────────────────────

/// Singleton [ForegroundScheduler] instance, disposed on app shutdown.
final foregroundSchedulerProvider = Provider<ForegroundScheduler>((ref) {
  final scheduler = ForegroundScheduler();
  ref.onDispose(() => scheduler.dispose());
  return scheduler;
});

// ── Config provider ───────────────────────────────────────────────

/// Manages the global [SchedulerConfig] state with Hive persistence.
///
/// UI widgets should watch this for reactive config updates.
final schedulerConfigProvider =
    NotifierProvider<SchedulerConfigNotifier, SchedulerConfig>(
      SchedulerConfigNotifier.new,
    );

// ── Scheduler service ─────────────────────────────────────────────

/// Provides the [CheckInSchedulerService] orchestrator.
///
/// The service reads config and tasks, then delegates execution to
/// [CheckInNotifier.executeCheckIn] via Riverpod's [Ref].
final checkInSchedulerServiceProvider = Provider<CheckInSchedulerService>((
  ref,
) {
  return CheckInSchedulerService(ref);
});

/// Whether the auto-check-in scheduler is currently active.
///
/// Watches [SchedulerConfig.enabled] for reactive status updates.
final checkInSchedulerStatusProvider = Provider<bool>((ref) {
  return ref.watch(schedulerConfigProvider).enabled;
});
