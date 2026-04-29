/// Application-wide network proxy preference.
///
/// Used as the fallback proxy for any [Account] whose
/// [Account.proxyMode] is `AccountProxyMode.followGlobal`. Account-level
/// modes [AccountProxyMode.direct] / [AccountProxyMode.custom] override
/// this setting.
library;

import '../../../../core/network/proxy_config.dart';

/// Immutable snapshot of the global proxy preference.
///
/// [enabled] is an independent toggle: even when [config] is non-null,
/// the global proxy must have [enabled] set to `true` before it takes
/// effect. This lets users keep proxy details on file while temporarily
/// disabling them.
class GlobalProxySetting {
  /// Whether the global proxy is currently active.
  final bool enabled;

  /// Proxy configuration. May be non-null even when [enabled] is `false`.
  final ProxyConfig? config;

  const GlobalProxySetting({this.enabled = false, this.config});

  /// Default disabled state, equivalent to "no global proxy configured".
  static const GlobalProxySetting disabled = GlobalProxySetting();

  GlobalProxySetting copyWith({bool? enabled, ProxyConfig? config}) {
    return GlobalProxySetting(
      enabled: enabled ?? this.enabled,
      config: config ?? this.config,
    );
  }

  /// Field-by-field equality helper that mirrors the convention used by
  /// other entities in this codebase.
  bool deepEquals(GlobalProxySetting other) {
    if (identical(this, other)) return true;
    return enabled == other.enabled && config == other.config;
  }
}
