/// Full-screen account edit / add page.
///
/// Replaces the legacy `AccountFormSheet`. Visual layout mirrors the
/// Stitch design (input/stitch_all_api_hub_flutter/_2_账号管理_编辑弹窗):
/// a compact AppBar with a close button, four grouped [SectionCard]s in
/// the body, and a pinned BottomAppBar hosting three actions (re-detect
/// placeholder, primary save, rocket_launch placeholder for managed
/// sites).
///
/// The page uses a [PopScope] to guard against accidental back / swipe
/// dismissal when the user has unsaved edits. A snapshot of the starting
/// form state is captured in [initState] and compared against the current
/// state to compute `_isDirty`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../tags/presentation/widgets/tag_chip_input.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/check_in_config.dart';
import '../providers/accounts_providers.dart';
import '../widgets/check_in_config_section.dart';

/// Full-screen account edit / add page.
class AccountEditPage extends ConsumerStatefulWidget {
  /// Existing account for edit mode; `null` for add mode.
  final Account? account;

  const AccountEditPage({super.key, this.account});

  /// Convenience push helper used from list entry points.
  static Future<void> push(BuildContext context, {Account? account}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccountEditPage(account: account),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
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
  late List<String> _tagIds;
  late CheckInConfig _checkIn;
  late String? _redemptionUrl;
  bool _obscureToken = true;
  bool _tokenModified = false;
  bool _isSubmitting = false;

  /// Snapshot of the form's initial state — used as the baseline for
  /// detecting unsaved edits without fighting `id` / `createdAt`.
  late final _FormSnapshot _initialSnapshot;

  bool get _isEditing => widget.account != null;

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
      text: a?.userId != null ? a!.userId.toString() : '',
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
    _tagIds = List<String>.from(a?.tagIds ?? const []);
    _checkIn = a?.checkIn ?? CheckInConfig.disabled;
    _redemptionUrl = a?.redemptionUrl;

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
      tagIds: _tagIds,
      checkIn: _checkIn,
      redemptionUrl: _redemptionUrl,
    );
  }

  @override
  void dispose() {
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
    tagIds: _tagIds,
    checkIn: _checkIn,
    redemptionUrl: _redemptionUrl,
  );

  bool get _isDirty => _currentSnapshot != _initialSnapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            _isEditing ? '编辑账号' : '新增账号',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: BottomAppBar(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    key: const ValueKey('reDetectButton'),
                    onPressed: _onReDetectPlaceholder,
                    child: const Text('重新识别'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('primarySaveButton'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? '保存更改' : '添加账号'),
                  ),
                ),
                if (_siteType.isManaged) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filledTonal(
                    key: const ValueKey('autoConfigButton'),
                    tooltip: '保存并配置',
                    icon: const Icon(Icons.rocket_launch),
                    onPressed: _onAutoConfigPlaceholder,
                  ),
                ],
              ],
            ),
          ),
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
          decoration: const InputDecoration(
            labelText: '站点 URL',
            hintText: 'https://api.example.com',
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          validator: _validateUrl,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('nameField'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: '站点名称'),
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
                decoration: const InputDecoration(labelText: '用户名'),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                key: const ValueKey('userIdField'),
                controller: _userIdController,
                decoration: const InputDecoration(labelText: '用户 ID'),
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
            labelText: '充值比例',
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
          ),
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

  // ─── Validators ────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入站点名称';
    if (value.trim().length > 50) return '名称不能超过 50 个字符';
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

  String? _validateNotes(String? value) {
    if (value != null && value.length > 200) return '备注不能超过 200 个字符';
    return null;
  }

  String? _validateUserId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return '请输入有效的数字';
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

  // ─── Actions ───────────────────────────────────────────────────────

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

  void _onReDetectPlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('自动识别功能即将上线～')));
  }

  void _onAutoConfigPlaceholder() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存并配置功能即将上线～')));
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final account = _buildAccountPayload();
      final notifier = ref.read(accountsProvider.notifier);
      final wasEnabledBefore = widget.account?.enabled ?? false;
      if (_isEditing) {
        await notifier.saveAccount(account);
      } else {
        await notifier.create(account);
      }

      // Mirror the old sheet's behaviour: if the account ends up enabled
      // and either just got flipped on or is brand new, kick a
      // reachability check. Fire-and-forget.
      final shouldRecheck =
          account.enabled && (!_isEditing || !wasEnabledBefore);
      if (shouldRecheck) {
        unawaited(notifier.checkOne(account.id));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? '账号 ${account.name} 已更新' : '账号 ${account.name} 已添加',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Account _buildAccountPayload() {
    final now = DateTime.now();

    // Access token: keep existing value if user didn't edit the field.
    final String? accessToken;
    if (_isEditing && !_tokenModified) {
      accessToken = widget.account!.accessToken;
    } else {
      accessToken = _tokenController.text.isEmpty
          ? null
          : _tokenController.text;
    }

    final parsedUserId = int.tryParse(_userIdController.text.trim());
    final parsedExchangeRate =
        double.tryParse(_exchangeRateController.text.trim()) ??
        kDefaultUsdToCnyRate;
    final parsedManualBalance = _manualBalanceController.text.trim().isEmpty
        ? null
        : double.tryParse(_manualBalanceController.text.trim());

    final username = _usernameController.text.trim().isEmpty
        ? null
        : _usernameController.text.trim();
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
      enabled: widget.account?.enabled ?? true,
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
  final List<String> tagIds;
  final CheckInConfig checkIn;
  final String? redemptionUrl;

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
    required this.tagIds,
    required this.checkIn,
    required this.redemptionUrl,
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
    required CheckInConfig checkIn,
    required String? redemptionUrl,
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
      tagIds: List<String>.from(tagIds),
      checkIn: checkIn,
      redemptionUrl: redemptionUrl,
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
    if (checkIn != other.checkIn) return false;
    if (redemptionUrl != other.redemptionUrl) return false;
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
    Object.hashAll(tagIds),
    checkIn,
    redemptionUrl,
  );
}
