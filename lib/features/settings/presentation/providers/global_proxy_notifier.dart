/// Notifier for the global proxy setting.
///
/// Provides methods to toggle the enabled state and update the proxy
/// configuration. All mutations persist to Hive via [GlobalProxyRepository].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/proxy_config.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/global_proxy_setting.dart';
import '../../domain/repositories/global_proxy_repository.dart';
import 'global_proxy_providers.dart';

class GlobalProxyNotifier extends AsyncNotifier<GlobalProxySetting> {
  @override
  Future<GlobalProxySetting> build() async {
    final result = await _repo.getCurrent();
    return switch (result) {
      Success(:final data) => data,
      Failure() => GlobalProxySetting.disabled,
    };
  }

  GlobalProxyRepository get _repo => ref.read(globalProxyRepositoryProvider);

  /// Toggles the enabled state of the global proxy.
  ///
  /// Persists the change immediately to Hive.
  Future<void> setEnabled(bool enabled) async {
    final current = state.valueOrNull ?? GlobalProxySetting.disabled;
    final updated = current.copyWith(enabled: enabled);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  /// Updates the proxy configuration.
  ///
  /// Persists the change immediately to Hive.
  Future<void> saveConfig(ProxyConfig? config) async {
    final current = state.valueOrNull ?? GlobalProxySetting.disabled;
    final updated = current.copyWith(config: config);
    state = AsyncData(updated);
    await _repo.save(updated);
  }

  /// Saves the complete global proxy setting.
  ///
  /// Persists the change immediately to Hive.
  Future<void> save(GlobalProxySetting setting) async {
    state = AsyncData(setting);
    await _repo.save(setting);
  }
}
