/// Riverpod providers for the global proxy setting (presentation layer).
///
/// Provides the [GlobalProxyNotifier] for UI-level mutations (save/toggle)
/// and a read-only [globalProxyProvider] for consuming the current state.
///
/// The data-layer repository provider is defined in
/// `lib/features/settings/data/providers/global_proxy_providers.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/proxy_config.dart';
import '../../domain/entities/global_proxy_setting.dart';
import '../../domain/repositories/global_proxy_repository.dart';
import '../../data/providers/global_proxy_providers.dart' as data;
import 'global_proxy_notifier.dart';

/// Provider for the [GlobalProxyRepository] implementation.
///
/// Re-exported from data layer for convenience.
final globalProxyRepositoryProvider = Provider<GlobalProxyRepository>((ref) {
  return ref.watch(data.globalProxyRepositoryProvider);
});

/// State notifier for the global proxy setting.
///
/// Use this provider to:
/// - Watch the current [GlobalProxySetting] state
/// - Call [GlobalProxyNotifier.setEnabled] to toggle the enabled state
/// - Call [GlobalProxyNotifier.saveConfig] to update the proxy configuration
/// - Call [GlobalProxyNotifier.save] to save the complete setting
final globalProxyProvider =
    AsyncNotifierProvider<GlobalProxyNotifier, GlobalProxySetting>(
      GlobalProxyNotifier.new,
    );

/// Convenience provider for checking if global proxy is enabled.
///
/// Returns `false` when the setting is still loading or on error.
final globalProxyEnabledProvider = Provider<bool>((ref) {
  final asyncSetting = ref.watch(globalProxyProvider);
  return asyncSetting.valueOrNull?.enabled ?? false;
});

/// Convenience provider for accessing the current proxy config.
///
/// Returns `null` when the setting is disabled, still loading, or on error.
final globalProxyConfigProvider = Provider<ProxyConfig?>((ref) {
  final asyncSetting = ref.watch(globalProxyProvider);
  final setting = asyncSetting.valueOrNull;
  if (setting == null || !setting.enabled) return null;
  return setting.config;
});
