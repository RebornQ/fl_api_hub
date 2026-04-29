/// Runtime proxy resolution logic.
///
/// Given an [Account]'s proxy mode and the current [GlobalProxySetting],
/// determines which [ProxyConfig] (if any) should be used for that
/// account's HTTP requests.
///
/// This is a pure function with no side effects or provider dependencies,
/// making it easy to unit test and safe to call from any layer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/domain/entities/account.dart';
import '../../features/settings/domain/entities/global_proxy_setting.dart';
import 'proxy_config.dart';

/// Resolves the effective [ProxyConfig] for an [Account] at request time.
///
/// Resolution priority (highest to lowest):
/// 1. [AccountProxyMode.direct] → force direct connection (returns `null`).
/// 2. [AccountProxyMode.custom] → use [Account.proxyConfig].
/// 3. [AccountProxyMode.followGlobal] → defer to [GlobalProxySetting]:
///    - If `enabled` and `config` is non-null → return global config.
///    - Otherwise → return `null` (direct connection).
class ProxyResolver {
  const ProxyResolver();

  /// Resolves the effective proxy configuration for [account].
  ///
  /// [global] is the current app-wide proxy setting.
  ///
  /// Returns `null` when no proxy should be used (direct connection).
  ProxyConfig? resolve(Account account, GlobalProxySetting global) {
    switch (account.proxyMode) {
      case AccountProxyMode.direct:
        // Explicit direct connection — ignore all proxy settings.
        return null;
      case AccountProxyMode.custom:
        // Use account-specific proxy configuration.
        return account.proxyConfig;
      case AccountProxyMode.followGlobal:
        // Defer to the global setting.
        return global.enabled ? global.config : null;
    }
  }
}

/// Riverpod provider for [ProxyResolver].
///
/// The resolver is a stateless pure-function class, so a simple [Provider]
/// suffices. Consumers should `ref.read` this provider and call [resolve]
/// with the account and current global setting — do not embed provider
/// reads inside the resolver itself to keep it testable.
final proxyResolverProvider = Provider<ProxyResolver>((ref) {
  return const ProxyResolver();
});
