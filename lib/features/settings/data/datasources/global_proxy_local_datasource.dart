/// Local data source for the global proxy setting.
///
/// Stores a single document in the dedicated `network_proxy` Hive box
/// under the [_configKey] key, mirroring the singleton pattern used by
/// the scheduler config data source.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../../accounts/data/models/account_mapper.dart';
import '../../domain/entities/global_proxy_setting.dart';

/// Box name for the global proxy setting.
const _boxName = 'network_proxy';

/// Singleton key used to store the active [GlobalProxySetting] document.
const _configKey = 'global_config';

/// Map keys used to serialize a [GlobalProxySetting].
const _kEnabled = 'enabled';
const _kConfig = 'config';

class GlobalProxyLocalDataSource {
  final Box _box;

  GlobalProxyLocalDataSource(this._box);

  /// Loads the saved global proxy setting, or returns
  /// [GlobalProxySetting.disabled] when nothing has been stored yet.
  GlobalProxySetting read() {
    final raw = _box.get(_configKey);
    if (raw is! Map) return GlobalProxySetting.disabled;
    final map = Map<String, dynamic>.from(raw);
    return GlobalProxySetting(
      enabled: map[_kEnabled] as bool? ?? false,
      config: AccountMapper.proxyConfigFromMap(map[_kConfig]),
    );
  }

  /// Persists [setting] to local storage.
  Future<void> write(GlobalProxySetting setting) async {
    await _box.put(_configKey, {
      _kEnabled: setting.enabled,
      _kConfig: AccountMapper.proxyConfigToMap(setting.config),
    });
  }
}

/// Riverpod provider for [GlobalProxyLocalDataSource].
///
/// Assumes [initHive] has already opened the `network_proxy` box.
final globalProxyLocalDataSourceProvider = Provider<GlobalProxyLocalDataSource>(
  (ref) {
    return GlobalProxyLocalDataSource(Hive.box(_boxName));
  },
);
