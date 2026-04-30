/// Proxy configuration section for the account edit form.
///
/// Displays a section with:
/// - Three-state mode selector (followGlobal / custom / direct)
/// - Proxy fields (scheme, host, port, username, password) when custom
/// - Test proxy button
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/proxy_config.dart';
import '../../../../core/network/proxy_test_service.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/entities/account.dart';

/// Proxy configuration section used inside the account edit page.
class ProxyConfigSection extends ConsumerStatefulWidget {
  /// Current proxy mode.
  final AccountProxyMode proxyMode;

  /// Current proxy configuration (only used when mode is custom).
  final ProxyConfig? proxyConfig;

  /// Account base URL used as the test target.
  final String? baseUrl;

  /// Called when the proxy mode changes.
  final ValueChanged<AccountProxyMode> onModeChanged;

  /// Called when the proxy configuration changes (in custom mode).
  final ValueChanged<ProxyConfig?> onConfigChanged;

  const ProxyConfigSection({
    super.key,
    required this.proxyMode,
    required this.proxyConfig,
    required this.baseUrl,
    required this.onModeChanged,
    required this.onConfigChanged,
  });

  @override
  ConsumerState<ProxyConfigSection> createState() => _ProxyConfigSectionState();
}

class _ProxyConfigSectionState extends ConsumerState<ProxyConfigSection> {
  bool _obscurePassword = true;
  bool _isTesting = false;

  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late ProxyScheme _scheme;

  Timer? _debounceTimer;
  ProxyConfig? _lastEmittedConfig;

  @override
  void initState() {
    super.initState();
    final config = widget.proxyConfig;
    _hostController = TextEditingController(text: config?.host ?? '');
    _portController = TextEditingController(
      text: config?.port.toString() ?? '',
    );
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(text: config?.password ?? '');
    _scheme = config?.scheme ?? ProxyScheme.http;
  }

  @override
  void didUpdateWidget(covariant ProxyConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync scheme when external config changes (e.g., form reset).
    // Note: We intentionally DON'T sync text controllers here because
    // modifying TextEditingController.value during build triggers
    // Form.setState() which throws "setState() called during build".
    // Controllers are initialized once in initState and updated only by user input.
    if (widget.proxyConfig?.scheme != _scheme) {
      _scheme = widget.proxyConfig?.scheme ?? ProxyScheme.http;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onModeSelected(AccountProxyMode mode) {
    widget.onModeChanged(mode);
    // Clear proxy config when switching away from custom.
    if (mode != AccountProxyMode.custom) {
      widget.onConfigChanged(null);
    }
  }

  void _emitConfig() {
    // Debounce to avoid rebuilding parent on every keystroke.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _doEmitConfig();
    });
  }

  void _doEmitConfig() {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 0;

    ProxyConfig? newConfig;
    if (host.isNotEmpty && port > 0 && port <= 65535) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // Auth fields must be both empty or both filled (PRD R3).
      final authValid =
          (username.isEmpty && password.isEmpty) ||
          (username.isNotEmpty && password.isNotEmpty);

      if (authValid) {
        newConfig = ProxyConfig(
          scheme: _scheme,
          host: host,
          port: port,
          username: username.isEmpty ? null : username,
          password: password.isEmpty ? null : password,
        );
      }
    }

    // Only notify parent if config actually changed.
    if (newConfig != _lastEmittedConfig) {
      _lastEmittedConfig = newConfig;
      widget.onConfigChanged(newConfig);
    }
  }

  Future<void> _testProxy() async {
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
      final result = await service.test(
        proxy: testConfig,
        targetUrl: widget.baseUrl,
      );

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SectionCard(
      icon: Icons.lan_outlined,
      title: '网络代理',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode selector.
          SegmentedButton<AccountProxyMode>(
            segments: const [
              ButtonSegment(
                value: AccountProxyMode.followGlobal,
                label: Text('跟随全局'),
              ),
              ButtonSegment(value: AccountProxyMode.custom, label: Text('自定义')),
              ButtonSegment(value: AccountProxyMode.direct, label: Text('直连')),
            ],
            selected: {widget.proxyMode},
            onSelectionChanged: (modes) {
              if (modes.isNotEmpty) _onModeSelected(modes.first);
            },
          ),
          if (widget.proxyMode == AccountProxyMode.custom) ...[
            const SizedBox(height: AppSpacing.md),
            _buildCustomFields(),
          ],
          if (kIsWeb) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Web 端代理由浏览器决定，配置不会生效',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomFields() {
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
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _scheme = value);
                    _emitConfig();
                  }
                },
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
                validator: _validateHost,
                onChanged: (_) => _emitConfig(),
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
          validator: _validatePort,
          onChanged: (_) => _emitConfig(),
        ),
        const SizedBox(height: AppSpacing.md),
        // Username field.
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '可选，代理认证用户名',
          ),
          textInputAction: TextInputAction.next,
          onChanged: (_) => _emitConfig(),
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
          onChanged: (_) => _emitConfig(),
        ),
        const SizedBox(height: AppSpacing.md),
        // Test button (hidden on web).
        if (!kIsWeb)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _isTesting ? null : _testProxy,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.network_check),
              label: Text(_isTesting ? '测试中...' : '测试代理'),
            ),
          ),
      ],
    );
  }

  String? _validateHost(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入代理主机地址';
    }
    if (value.trim().contains('://')) {
      return '不要带 http:// 或 https:// 前缀';
    }
    return null;
  }

  String? _validatePort(String? value) {
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
