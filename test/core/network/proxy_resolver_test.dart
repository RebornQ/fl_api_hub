import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/network/proxy_config.dart';
import 'package:fl_api_hub/core/network/proxy_resolver.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/features/accounts/domain/entities/account.dart';
import 'package:fl_api_hub/features/settings/domain/entities/global_proxy_setting.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

/// Minimal [Account] fixture for proxy resolution tests.
Account _account({
  AccountProxyMode proxyMode = AccountProxyMode.followGlobal,
  ProxyConfig? proxyConfig,
}) {
  return Account(
    id: 'test-id',
    name: 'Test',
    baseUrl: 'https://example.com',
    siteType: SiteType.newApi,
    authType: AuthType.accessToken,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    proxyMode: proxyMode,
    proxyConfig: proxyConfig,
  );
}

const _testProxy = ProxyConfig(
  scheme: ProxyScheme.http,
  host: 'proxy.example.com',
  port: 8080,
);

const _globalProxy = ProxyConfig(
  scheme: ProxyScheme.https,
  host: 'global-proxy.example.com',
  port: 3128,
  username: 'user',
  password: 'pass',
);

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late ProxyResolver resolver;

  setUp(() {
    resolver = const ProxyResolver();
  });

  group('AccountProxyMode.direct', () {
    test('returns null regardless of global setting', () {
      final account = _account(proxyMode: AccountProxyMode.direct);
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      expect(resolver.resolve(account, global), isNull);
    });

    test('returns null even when account has proxyConfig', () {
      final account = _account(
        proxyMode: AccountProxyMode.direct,
        proxyConfig: _testProxy,
      );
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      expect(resolver.resolve(account, global), isNull);
    });
  });

  group('AccountProxyMode.custom', () {
    test('returns account proxyConfig when set', () {
      final account = _account(
        proxyMode: AccountProxyMode.custom,
        proxyConfig: _testProxy,
      );
      final global = GlobalProxySetting.disabled;

      expect(resolver.resolve(account, global), _testProxy);
    });

    test('returns null when account proxyConfig is null', () {
      final account = _account(
        proxyMode: AccountProxyMode.custom,
        proxyConfig: null,
      );
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      // custom mode with null config means "no proxy", even though global
      // is enabled — custom mode overrides global.
      expect(resolver.resolve(account, global), isNull);
    });

    test('ignores global setting', () {
      final account = _account(
        proxyMode: AccountProxyMode.custom,
        proxyConfig: _testProxy,
      );
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      // Should return the account's proxy, not the global one.
      final result = resolver.resolve(account, global);
      expect(result, isNotNull);
      expect(result!.host, 'proxy.example.com');
    });
  });

  group('AccountProxyMode.followGlobal', () {
    test('returns global config when global is enabled', () {
      final account = _account(proxyMode: AccountProxyMode.followGlobal);
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      final result = resolver.resolve(account, global);
      expect(result, _globalProxy);
    });

    test('returns null when global is disabled', () {
      final account = _account(proxyMode: AccountProxyMode.followGlobal);
      const global = GlobalProxySetting(enabled: false, config: _globalProxy);

      // Global has a config but is disabled.
      expect(resolver.resolve(account, global), isNull);
    });

    test('returns null when global is enabled but config is null', () {
      final account = _account(proxyMode: AccountProxyMode.followGlobal);
      const global = GlobalProxySetting(enabled: true);

      // Enabled but no config — nothing to proxy through.
      expect(resolver.resolve(account, global), isNull);
    });

    test('returns null when global is default disabled', () {
      final account = _account(proxyMode: AccountProxyMode.followGlobal);
      const global = GlobalProxySetting.disabled;

      expect(resolver.resolve(account, global), isNull);
    });

    test('ignores account proxyConfig', () {
      final account = _account(
        proxyMode: AccountProxyMode.followGlobal,
        proxyConfig: _testProxy,
      );
      const global = GlobalProxySetting.disabled;

      // followGlobal ignores the account-level config.
      expect(resolver.resolve(account, global), isNull);
    });
  });

  group('Priority ordering', () {
    test('direct takes precedence over custom and global', () {
      final account = _account(
        proxyMode: AccountProxyMode.direct,
        proxyConfig: _testProxy,
      );
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      expect(resolver.resolve(account, global), isNull);
    });

    test('custom takes precedence over global', () {
      final account = _account(
        proxyMode: AccountProxyMode.custom,
        proxyConfig: _testProxy,
      );
      final global = GlobalProxySetting(enabled: true, config: _globalProxy);

      final result = resolver.resolve(account, global);
      expect(result, _testProxy);
      expect(result, isNot(_globalProxy));
    });
  });
}
