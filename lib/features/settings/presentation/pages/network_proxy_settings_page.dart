/// Full-screen network proxy settings page.
///
/// Provides:
/// - Enable/disable toggle for global proxy
/// - Proxy configuration fields (scheme, host, port, username, password)
/// - Test proxy connectivity button
/// - PopScope confirmation for unsaved changes
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/proxy_config.dart';
import '../../../../core/network/proxy_test_service.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/global_proxy_setting.dart';
import '../providers/global_proxy_providers.dart';

/// Full-screen network proxy settings page.
class NetworkProxySettingsPage extends ConsumerStatefulWidget {
  const NetworkProxySettingsPage({super.key});

  /// Convenience push helper.
  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const NetworkProxySettingsPage(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<NetworkProxySettingsPage> createState() =>
      _NetworkProxySettingsPageState();
}

class _NetworkProxySettingsPageState
    extends ConsumerState<NetworkProxySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isTesting = false;
  bool _obscurePassword = true;

  // Form controllers.
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late ProxyScheme _scheme;
  late bool _enabled;

  // Initial snapshot for dirty detection.
  late _FormSnapshot _initialSnapshot;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty defaults; will sync in didChangeDependencies.
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _scheme = ProxyScheme.http;
    _enabled = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync controllers from provider state (only once on first load).
    if (_initialized) return;
    final setting = ref.read(globalProxyProvider).valueOrNull;
    _syncControllersFromSetting(setting ?? GlobalProxySetting.disabled);
    _initialSnapshot = _currentSnapshot;
    _initialized = true;
  }

  void _syncControllersFromSetting(GlobalProxySetting setting) {
    final config = setting.config;
    _hostController.text = config?.host ?? '';
    _portController.text = config?.port.toString() ?? '';
    _usernameController.text = config?.username ?? '';
    _passwordController.text = config?.password ?? '';
    _scheme = config?.scheme ?? ProxyScheme.http;
    _enabled = setting.enabled;
  }

  _FormSnapshot get _currentSnapshot => _FormSnapshot(
    enabled: _enabled,
    scheme: _scheme,
    host: _hostController.text.trim(),
    port: _portController.text.trim(),
    username: _usernameController.text.trim(),
    password: _passwordController.text.trim(),
  );

  bool get _isDirty => _currentSnapshot != _initialSnapshot;

  /// Returns true if the current proxy configuration is valid for saving.
  ///
  /// When enabled is true, host must be non-empty and port must be in range.
  /// When enabled is false, no validation is needed (config can be empty).
  bool get _isConfigValid {
    if (!_enabled) return true; // Disabled state is always valid.
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 0;
    return host.isNotEmpty && port > 0 && port <= 65535;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final config = _buildConfigFromForm();
      final setting = GlobalProxySetting(enabled: _enabled, config: config);
      await ref.read(globalProxyProvider.notifier).save(setting);
      if (!mounted) return;
      // Update initial snapshot to clear dirty state.
      _initialSnapshot = _currentSnapshot;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('全局代理设置已保存')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ProxyConfig? _buildConfigFromForm() {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 0;

    if (host.isEmpty || port <= 0 || port > 65535) return null;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    return ProxyConfig(
      scheme: _scheme,
      host: host,
      port: port,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );
  }

  Future<void> _testProxy() async {
    if (_isTesting) return;

    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 0;

    // Validate before testing.
    if (host.isEmpty) {
      _showSnackBar('请输入代理主机地址', isError: true);
      return;
    }
    if (port <= 0 || port > 65535) {
      _showSnackBar('请输入有效的端口号 (1-65535)', isError: true);
      return;
    }

    // Check if host contains protocol prefix.
    if (host.contains('://')) {
      _showSnackBar('主机地址不要带协议前缀（http:// 或 https://）', isError: true);
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Validate auth fields consistency.
    if ((username.isNotEmpty && password.isEmpty) ||
        (username.isEmpty && password.isNotEmpty)) {
      _showSnackBar('用户名和密码必须同时填写或同时留空', isError: true);
      return;
    }

    setState(() => _isTesting = true);

    try {
      final testConfig = ProxyConfig(
        scheme: _scheme,
        host: host,
        port: port,
        username: username.isEmpty ? null : username,
        password: password.isEmpty ? null : password,
      );

      final service = ref.read(proxyTestServiceProvider);
      final result = await service.test(proxy: testConfig);

      if (!mounted) return;

      switch (result) {
        case ProxyTestSuccess(:final latency):
          _showSnackBar('代理可用，延迟 ${latency.inMilliseconds}ms', isError: false);
        case ProxyTestFailure(:final reason):
          _showSnackBar('代理测试失败：$reason', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? colors.error : colors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? colors.errorContainer
            : colors.primaryContainer.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await _confirmDiscardChanges();
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃未保存的更改？'),
        content: const Text('你有尚未保存的修改，离开将会丢失。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Watch provider to sync state.
    final asyncSetting = ref.watch(globalProxyProvider);
    if (asyncSetting.hasValue && !_isDirty) {
      // Sync from provider only when not dirty (user hasn't made changes).
      final setting = asyncSetting.value!;
      if (_enabled != setting.enabled ||
          _currentSnapshot.config != setting.config) {
        // Defer setState to avoid build-time mutation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDirty) {
            _syncControllersFromSetting(setting);
            setState(() {});
          }
        });
      }
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: _requestClose,
          ),
          title: Text(
            '网络代理',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.primary,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Info banner above the toggle.
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '全局代理对设置为「跟随全局」的账号生效。账号可单独配置代理覆盖此设置。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Enable toggle.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  color: colors.surfaceContainerLow,
                  child: SwitchListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    secondary: const Icon(Icons.toggle_on_outlined),
                    title: const Text('启用全局代理'),
                    subtitle: Text(_enabled ? '已启用，账号默认通过代理访问' : '未启用，账号直连访问'),
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Proxy server section.
              SectionCard(
                icon: Icons.dns_outlined,
                title: '代理服务器',
                child: _buildProxyFields(),
              ),
              const SizedBox(height: AppSpacing.md),
              // Auth section.
              SectionCard(
                icon: Icons.vpn_key_outlined,
                title: '认证（可选）',
                child: _buildAuthFields(),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Test button.
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'Web 端代理由浏览器决定，无法测试',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!kIsWeb)
                IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 40,
                        child: FilledButton.tonalIcon(
                          onPressed: (!_enabled || _isTesting)
                              ? null
                              : _testProxy,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check),
                          label: Text(_isTesting ? '测试中...' : '测试代理'),
                        ),
                      ),
                      if (_isDirty) ...[
                        const SizedBox(height: AppSpacing.md),
                        if (_enabled && !_isConfigValid)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              '请填写完整的主机地址和端口',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          height: 40,
                          child: FilledButton.tonalIcon(
                            onPressed: (_isSaving || !_isConfigValid)
                                ? null
                                : _onSave,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_isSaving ? '保存中...' : '保存'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProxyFields() {
    final fieldsEnabled = _enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scheme dropdown + Host field.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scheme dropdown.
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<ProxyScheme>(
                initialValue: _scheme,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '协议'),
                items: ProxyScheme.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: fieldsEnabled
                    ? (value) {
                        if (value != null) {
                          setState(() => _scheme = value);
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Host field.
            Expanded(
              child: TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: '主机地址 *',
                  hintText: 'proxy.example.com',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                enabled: fieldsEnabled,
                validator: _validateHost,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Port field.
        TextFormField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: '端口 *',
            hintText: '8080',
          ),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          enabled: fieldsEnabled,
          validator: _validatePort,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildAuthFields() {
    final fieldsEnabled = _enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Username field.
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '可选，代理认证用户名',
          ),
          textInputAction: TextInputAction.next,
          enabled: fieldsEnabled,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        // Password field.
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '可选，代理认证密码',
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          enabled: fieldsEnabled,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  String? _validateHost(String? value) {
    if (!_enabled) return null; // Skip validation when disabled.
    if (value == null || value.trim().isEmpty) {
      return '请输入代理主机地址';
    }
    if (value.trim().contains('://')) {
      return '不要带 http:// 或 https:// 前缀';
    }
    return null;
  }

  String? _validatePort(String? value) {
    if (!_enabled) return null; // Skip validation when disabled.
    if (value == null || value.trim().isEmpty) {
      return '请输入端口号';
    }
    final port = int.tryParse(value.trim());
    if (port == null) {
      return '请输入有效的数字';
    }
    if (port <= 0 || port > 65535) {
      return '端口号范围: 1-65535';
    }
    return null;
  }
}

/// Immutable snapshot of the form state for dirty detection.
@immutable
class _FormSnapshot {
  final bool enabled;
  final ProxyScheme scheme;
  final String host;
  final String port;
  final String username;
  final String password;

  const _FormSnapshot({
    required this.enabled,
    required this.scheme,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  ProxyConfig? get config {
    final portNum = int.tryParse(port) ?? 0;
    if (host.isEmpty || portNum <= 0 || portNum > 65535) return null;
    return ProxyConfig(
      scheme: scheme,
      host: host,
      port: portNum,
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FormSnapshot &&
        enabled == other.enabled &&
        scheme == other.scheme &&
        host == other.host &&
        port == other.port &&
        username == other.username &&
        password == other.password;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, scheme, host, port, username, password);
}
