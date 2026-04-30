/// Reusable account edit form widget.
///
/// Contains the four grouped [SectionCard] sections (site info, credentials,
/// check-in config, metadata) and all associated validation logic.
///
/// Use via [GlobalKey<AccountEditFormState>] to access [isDirty], [submit],
/// and [resetSnapshot].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/proxy_config.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../tags/presentation/widgets/tag_chip_input.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/check_in_config.dart';
import '../providers/accounts_providers.dart';
import '../widgets/check_in_config_section.dart';
import '../widgets/proxy_config_section.dart';

/// Reusable account edit form.
///
/// Parents access the form's state through a [GlobalKey<AccountEditFormState>]
/// to check [isDirty], trigger [submit], or [resetSnapshot] after an external
/// save.
class AccountEditForm extends ConsumerStatefulWidget {
  /// Existing account for edit mode; `null` for add mode.
  final Account? account;

  /// Optional notifier that mirrors [AccountEditFormState.isDirty].
  /// Updated on every build so the parent can react (e.g. [PopScope]).
  final ValueNotifier<bool>? dirtyNotifier;

  /// Optional notifier that mirrors the form's current [SiteType].
  /// Parents can use this to conditionally show widgets (e.g. the
  /// managed-site auto-config button) without reaching into the form state.
  final ValueNotifier<SiteType>? siteTypeNotifier;

  const AccountEditForm({
    super.key,
    this.account,
    this.dirtyNotifier,
    this.siteTypeNotifier,
  });

  @override
  ConsumerState<AccountEditForm> createState() => AccountEditFormState();
}

class AccountEditFormState extends ConsumerState<AccountEditForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _notesController;
  late final TextEditingController _usernameController;
  late final TextEditingController _userIdController;
  late final TextEditingController _exchangeRateController;
  late final TextEditingController _manualBalanceController;

  late SiteType _siteType;
  late AuthType _authType;
  late bool _excludeFromTotalBalance;
  late bool _enabled;
  late List<String> _tagIds;
  late CheckInConfig _checkIn;
  late String? _redemptionUrl;
  bool _obscureToken = true;
  bool _tokenModified = false;
  bool _isSubmitting = false;

  late AccountProxyMode _proxyMode;
  ProxyConfig? _proxyConfig;

  final _urlFocusNode = FocusNode();
  Timer? _urlDebounce;
  bool _isDuplicateUrl = false;
  List<String> _duplicateUrlNames = const [];

  late _FormSnapshot _initialSnapshot;

  bool get _isEditing => widget.account != null;

  bool get isDirty => _currentSnapshot != _initialSnapshot;

  bool get isSubmitting => _isSubmitting;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _nameController = TextEditingController(text: a?.name ?? '');
    _urlController = TextEditingController(text: a?.baseUrl ?? '');
    _tokenController = TextEditingController(text: a?.accessToken ?? '');
    _notesController = TextEditingController(text: a?.notes ?? '');
    _usernameController = TextEditingController(text: a?.username ?? '');
    _userIdController = TextEditingController(
      text: (a != null && a.userId > 0) ? a.userId.toString() : '',
    );
    _exchangeRateController = TextEditingController(
      text: (a?.exchangeRate ?? kDefaultUsdToCnyRate).toString(),
    );
    _manualBalanceController = TextEditingController(
      text: a?.manualBalanceUsd != null ? a!.manualBalanceUsd.toString() : '',
    );

    _siteType = a?.siteType ?? SiteType.newApi;
    _authType = a?.authType ?? _siteType.defaultAuthType;
    _excludeFromTotalBalance = a?.excludeFromTotalBalance ?? false;
    _enabled = a?.enabled ?? true;
    _tagIds = List<String>.from(a?.tagIds ?? const []);
    _checkIn = a?.checkIn ?? CheckInConfig.disabled;
    _redemptionUrl = a?.redemptionUrl;
    _proxyMode = a?.proxyMode ?? AccountProxyMode.followGlobal;
    _proxyConfig = a?.proxyConfig;

    _initialSnapshot = _FormSnapshot.fromControllers(
      name: _nameController.text,
      baseUrl: _urlController.text,
      accessToken: _tokenController.text,
      notes: _notesController.text,
      username: _usernameController.text,
      userId: _userIdController.text,
      exchangeRate: _exchangeRateController.text,
      manualBalance: _manualBalanceController.text,
      siteType: _siteType,
      authType: _authType,
      excludeFromTotalBalance: _excludeFromTotalBalance,
      enabled: _enabled,
      tagIds: _tagIds,
      checkIn: _checkIn,
      redemptionUrl: _redemptionUrl,
      proxyMode: _proxyMode,
      proxyConfig: _proxyConfig,
    );

    _urlFocusNode.addListener(_onUrlFocusChanged);
  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _urlFocusNode.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _notesController.dispose();
    _usernameController.dispose();
    _userIdController.dispose();
    _exchangeRateController.dispose();
    _manualBalanceController.dispose();
    super.dispose();
  }

  _FormSnapshot get _currentSnapshot => _FormSnapshot.fromControllers(
    name: _nameController.text,
    baseUrl: _urlController.text,
    accessToken: _tokenController.text,
    notes: _notesController.text,
    username: _usernameController.text,
    userId: _userIdController.text,
    exchangeRate: _exchangeRateController.text,
    manualBalance: _manualBalanceController.text,
    siteType: _siteType,
    authType: _authType,
    excludeFromTotalBalance: _excludeFromTotalBalance,
    enabled: _enabled,
    tagIds: _tagIds,
    checkIn: _checkIn,
    redemptionUrl: _redemptionUrl,
    proxyMode: _proxyMode,
    proxyConfig: _proxyConfig,
  );

  /// Resets the dirty baseline to the current form state.
  void resetSnapshot() {
    _initialSnapshot = _currentSnapshot;
    widget.dirtyNotifier?.value = false;
  }

  /// Validates and saves the form.
  ///
  /// Returns the saved [Account] on success, or `null` if validation failed
  /// or the save threw. Shows a [SnackBar] on error.
  Future<Account?> submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return null;

    setState(() => _isSubmitting = true);

    try {
      final account = _buildAccountPayload();
      final notifier = ref.read(accountsProvider.notifier);
      if (_isEditing) {
        await notifier.saveAccount(account);
      } else {
        await notifier.create(account);
      }

      final shouldRecheck = account.enabled;
      if (shouldRecheck) {
        unawaited(notifier.checkOne(account.id));
      }

      if (!mounted) return null;

      resetSnapshot();
      return account;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      return null;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync dirty state to parent notifier on every rebuild.
    final dirty = isDirty;
    final dNotifier = widget.dirtyNotifier;
    if (dNotifier != null && dNotifier.value != dirty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && dNotifier.value != isDirty) {
          dNotifier.value = isDirty;
        }
      });
    }

    // Sync current site type to parent notifier.
    final stNotifier = widget.siteTypeNotifier;
    if (stNotifier != null && stNotifier.value != _siteType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && stNotifier.value != _siteType) {
          stNotifier.value = _siteType;
        }
      });
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '启用此账号',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '禁用后，该账号将不参与签到操作',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.language,
              title: '站点信息',
              child: _buildSiteInfoFields(),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.key,
              title: '认证凭据',
              child: _buildCredentialsFields(),
            ),
            const SizedBox(height: AppSpacing.md),
            ProxyConfigSection(
              key: const ValueKey('proxyConfigSection'),
              proxyMode: _proxyMode,
              proxyConfig: _proxyConfig,
              baseUrl: _urlController.text.trim(),
              onModeChanged: (mode) => setState(() => _proxyMode = mode),
              onConfigChanged: (config) =>
                  setState(() => _proxyConfig = config),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.event_available,
              title: '签到配置',
              child: CheckInConfigSection(
                config: _checkIn,
                redemptionUrl: _redemptionUrl,
                onConfigChanged: (next) => setState(() => _checkIn = next),
                onRedemptionUrlChanged: (value) =>
                    setState(() => _redemptionUrl = value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              icon: Icons.label_important_outline,
              title: '元数据',
              child: _buildMetadataFields(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // ─── Section builders ──────────────────────────────────────────────

  Widget _buildSiteInfoFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const ValueKey('urlField'),
          controller: _urlController,
          focusNode: _urlFocusNode,
          decoration: _buildUrlDecoration(),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          validator: _validateUrl,
          onChanged: (_) {
            setState(() {});
            _urlDebounce?.cancel();
            _urlDebounce = Timer(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              _checkDuplicateUrl(_urlController.text);
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('nameField'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: '站点名称 *'),
                textInputAction: TextInputAction.next,
                validator: _validateName,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonFormField<SiteType>(
                key: const ValueKey('siteTypeField'),
                initialValue: _siteType,
                decoration: const InputDecoration(labelText: '站点类型'),
                items: SiteType.values
                    .where((t) => t != SiteType.anyrouter || _siteType == t)
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (t) {
                  if (t == null) return;
                  setState(() {
                    _siteType = t;
                    _authType = t.defaultAuthType;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('usernameField'),
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '用户名 *'),
                textInputAction: TextInputAction.next,
                validator: _validateUsername,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                key: const ValueKey('userIdField'),
                controller: _userIdController,
                decoration: const InputDecoration(labelText: '用户 ID *'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: _validateUserId,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey('exchangeRateField'),
          controller: _exchangeRateController,
          decoration: const InputDecoration(
            labelText: '充值比例 *',
            suffixText: 'CNY/USD',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          validator: _validateExchangeRate,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildCredentialsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AuthType>(
          key: const ValueKey('authTypeField'),
          initialValue: _authType,
          decoration: const InputDecoration(labelText: '认证方式'),
          items: AuthType.values
              .map(
                (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
              )
              .toList(),
          onChanged: (t) {
            if (t == null) return;
            setState(() => _authType = t);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey('accessTokenField'),
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: '访问令牌',
            hintText: _authType == AuthType.none
                ? '当前认证方式无需令牌'
                : '输入 API Token',
            suffixIcon: IconButton(
              tooltip: _obscureToken ? '显示令牌' : '隐藏令牌',
              icon: Icon(
                _obscureToken
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () {
                setState(() => _obscureToken = !_obscureToken);
              },
            ),
          ),
          obscureText: _obscureToken,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            _tokenModified = true;
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildMetadataFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '标签',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TagChipInput(
          selectedTagIds: _tagIds,
          onChanged: (next) => setState(() => _tagIds = next),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey('notesField'),
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '可选，输入备注信息',
            alignLabelWithHint: true,
          ),
          textAlignVertical: TextAlignVertical.top,
          maxLines: 3,
          validator: _validateNotes,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey('manualBalanceField'),
          controller: _manualBalanceController,
          decoration: const InputDecoration(
            labelText: '手动余额 (USD)',
            hintText: '留空则自动获取',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          validator: _validateManualBalance,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          key: const ValueKey('excludeFromTotalSwitch'),
          contentPadding: EdgeInsets.zero,
          title: Text('不计入总余额', style: Theme.of(context).textTheme.bodyMedium),
          subtitle: Text(
            '仅影响仪表盘总余额统计，不影响刷新 / 签到',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          value: _excludeFromTotalBalance,
          onChanged: (v) => setState(() => _excludeFromTotalBalance = v),
        ),
      ],
    );
  }

  // ─── URL decoration ───────────────────────────────────────────────

  /// Builds the InputDecoration for the URL field.
  ///
  /// When a duplicate URL is detected, shows an orange border, warning icon,
  /// and helper text naming the conflicting account(s).
  InputDecoration _buildUrlDecoration() {
    if (!_isDuplicateUrl) {
      return const InputDecoration(
        labelText: '站点 URL *',
        hintText: 'https://api.example.com',
      );
    }

    final names = _duplicateUrlNames;
    final message = names.length == 1
        ? '该 URL 已被账号「${names.first}」使用'
        : '该 URL 已被 ${names.length} 个账号使用：${names.take(3).join('、')}'
              '${names.length > 3 ? ' 等' : ''}';

    final warningColor = Theme.of(
      context,
    ).colorScheme.error.withValues(alpha: 0.7);

    return InputDecoration(
      labelText: '站点 URL *',
      labelStyle: TextStyle(color: warningColor),
      floatingLabelStyle: TextStyle(color: warningColor),
      hintText: 'https://api.example.com',
      suffixIcon: Tooltip(
        message: message,
        child: Icon(Icons.warning_amber_rounded, color: warningColor),
      ),
      helperText: message,
      helperStyle: TextStyle(color: warningColor),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: warningColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: warningColor, width: 2),
      ),
    );
  }

  // ─── Validators ────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入站点名称';
    if (value.trim().length > 50) return '名称不能超过 50 个字符';
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入用户名';
    if (value.trim().length > 50) return '用户名不能超过 50 个字符';
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入站点 URL';
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '请输入有效的 URL（以 http:// 或 https:// 开头）';
    }
    return null;
  }

  /// Normalizes a URL for duplicate comparison.
  static String _normalizeUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.toLowerCase();
  }

  /// Checks if [rawUrl] matches any existing account's base URL.
  void _checkDuplicateUrl(String rawUrl) {
    final normalized = _normalizeUrl(rawUrl);
    if (normalized.isEmpty ||
        (!normalized.startsWith('http://') &&
            !normalized.startsWith('https://'))) {
      if (_isDuplicateUrl || _duplicateUrlNames.isNotEmpty) {
        setState(() {
          _isDuplicateUrl = false;
          _duplicateUrlNames = const [];
        });
      }
      return;
    }

    final accounts = ref.read(accountsProvider).valueOrNull ?? <Account>[];
    final currentId = widget.account?.id;
    final matches = accounts.where((a) {
      if (a.id == currentId) return false;
      return _normalizeUrl(a.baseUrl) == normalized;
    }).toList();

    final hasDuplicate = matches.isNotEmpty;
    final names = matches.map((a) => a.name).toList();

    if (hasDuplicate != _isDuplicateUrl ||
        names.length != _duplicateUrlNames.length ||
        !names.asMap().keys.every(
          (i) =>
              i < _duplicateUrlNames.length &&
              names[i] == _duplicateUrlNames[i],
        )) {
      setState(() {
        _isDuplicateUrl = hasDuplicate;
        _duplicateUrlNames = names;
      });
    }
  }

  /// Triggered when URL field gains or loses focus.
  void _onUrlFocusChanged() {
    if (!_urlFocusNode.hasFocus) {
      _urlDebounce?.cancel();
      _checkDuplicateUrl(_urlController.text);
    }
  }

  String? _validateNotes(String? value) {
    if (value != null && value.length > 200) return '备注不能超过 200 个字符';
    return null;
  }

  String? _validateUserId(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入用户 ID';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return '请输入有效的数字';
    if (parsed <= 0) return '请输入大于 0 的正整数';
    return null;
  }

  String? _validateExchangeRate(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入充值比例';
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return '请输入大于 0 的有效数字';
    }
    return null;
  }

  String? _validateManualBalance(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return '请输入大于等于 0 的有效数字';
    }
    return null;
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  Account _buildAccountPayload() {
    final now = DateTime.now();

    final String? accessToken;
    if (_isEditing && !_tokenModified) {
      accessToken = widget.account!.accessToken;
    } else {
      accessToken = _tokenController.text.isEmpty
          ? null
          : _tokenController.text;
    }

    final parsedUserId = int.tryParse(_userIdController.text.trim()) ?? -1;
    final parsedExchangeRate =
        double.tryParse(_exchangeRateController.text.trim()) ??
        kDefaultUsdToCnyRate;
    final parsedManualBalance = _manualBalanceController.text.trim().isEmpty
        ? null
        : double.tryParse(_manualBalanceController.text.trim());

    final username = _usernameController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    return Account(
      id: widget.account?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      baseUrl: _urlController.text.trim(),
      siteType: _siteType,
      authType: _authType,
      accessToken: accessToken,
      enabled: _enabled,
      notes: notes,
      balance: widget.account?.balance,
      username: username,
      userId: parsedUserId,
      exchangeRate: parsedExchangeRate,
      manualBalanceUsd: parsedManualBalance,
      excludeFromTotalBalance: _excludeFromTotalBalance,
      tagIds: List<String>.from(_tagIds),
      checkIn: _checkIn,
      redemptionUrl: _redemptionUrl,
      createdAt: widget.account?.createdAt ?? now,
      updatedAt: now,
      proxyMode: _proxyMode,
      proxyConfig: _proxyMode == AccountProxyMode.custom ? _proxyConfig : null,
    );
  }
}

/// Value-equality snapshot of the user-editable form state.
///
/// Kept separate from [Account] so `isDirty` computations aren't skewed
/// by derived fields (`id`, `createdAt`, `balance`) that the user cannot
/// edit directly.
@immutable
class _FormSnapshot {
  final String name;
  final String baseUrl;
  final String accessToken;
  final String notes;
  final String username;
  final String userId;
  final String exchangeRate;
  final String manualBalance;
  final SiteType siteType;
  final AuthType authType;
  final bool excludeFromTotalBalance;
  final bool enabled;
  final List<String> tagIds;
  final CheckInConfig checkIn;
  final String? redemptionUrl;
  final AccountProxyMode proxyMode;
  final ProxyConfig? proxyConfig;

  const _FormSnapshot({
    required this.name,
    required this.baseUrl,
    required this.accessToken,
    required this.notes,
    required this.username,
    required this.userId,
    required this.exchangeRate,
    required this.manualBalance,
    required this.siteType,
    required this.authType,
    required this.excludeFromTotalBalance,
    required this.enabled,
    required this.tagIds,
    required this.checkIn,
    required this.redemptionUrl,
    required this.proxyMode,
    required this.proxyConfig,
  });

  factory _FormSnapshot.fromControllers({
    required String name,
    required String baseUrl,
    required String accessToken,
    required String notes,
    required String username,
    required String userId,
    required String exchangeRate,
    required String manualBalance,
    required SiteType siteType,
    required AuthType authType,
    required bool excludeFromTotalBalance,
    required List<String> tagIds,
    required bool enabled,
    required CheckInConfig checkIn,
    required String? redemptionUrl,
    required AccountProxyMode proxyMode,
    required ProxyConfig? proxyConfig,
  }) {
    return _FormSnapshot(
      name: name,
      baseUrl: baseUrl,
      accessToken: accessToken,
      notes: notes,
      username: username,
      userId: userId,
      exchangeRate: exchangeRate,
      manualBalance: manualBalance,
      siteType: siteType,
      authType: authType,
      excludeFromTotalBalance: excludeFromTotalBalance,
      enabled: enabled,
      tagIds: List<String>.from(tagIds),
      checkIn: checkIn,
      redemptionUrl: redemptionUrl,
      proxyMode: proxyMode,
      proxyConfig: proxyConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _FormSnapshot) return false;
    if (name != other.name) return false;
    if (baseUrl != other.baseUrl) return false;
    if (accessToken != other.accessToken) return false;
    if (notes != other.notes) return false;
    if (username != other.username) return false;
    if (userId != other.userId) return false;
    if (exchangeRate != other.exchangeRate) return false;
    if (manualBalance != other.manualBalance) return false;
    if (siteType != other.siteType) return false;
    if (authType != other.authType) return false;
    if (excludeFromTotalBalance != other.excludeFromTotalBalance) return false;
    if (enabled != other.enabled) return false;
    if (checkIn != other.checkIn) return false;
    if (redemptionUrl != other.redemptionUrl) return false;
    if (proxyMode != other.proxyMode) return false;
    if (proxyConfig != other.proxyConfig) return false;
    if (tagIds.length != other.tagIds.length) return false;
    for (var i = 0; i < tagIds.length; i++) {
      if (tagIds[i] != other.tagIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    name,
    baseUrl,
    accessToken,
    notes,
    username,
    userId,
    exchangeRate,
    manualBalance,
    siteType,
    authType,
    excludeFromTotalBalance,
    enabled,
    Object.hashAll(tagIds),
    checkIn,
    redemptionUrl,
    proxyMode,
    proxyConfig,
  );
}
