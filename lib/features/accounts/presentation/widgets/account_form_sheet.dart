/// Modal bottom sheet form for adding or editing an [Account].
///
/// When [account] is `null`, the form operates in add mode. Otherwise it
/// pre-populates all fields from the given account (including loading the
/// existing access token from secure storage).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/account.dart';
import '../providers/accounts_providers.dart';

/// A bottom-sheet form for creating or editing an account.
class AccountFormSheet extends ConsumerStatefulWidget {
  /// Existing account for edit mode; `null` for add mode.
  final Account? account;

  const AccountFormSheet({super.key, this.account});

  /// Opens the form as a modal bottom sheet.
  static Future<void> show(BuildContext context, {Account? account}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AccountFormSheet(account: account),
    );
  }

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _notesController;

  late SiteType _selectedSiteType;
  late AuthType _selectedAuthType;
  late bool _enabled;
  bool _obscureToken = true;
  bool _tokenLoaded = false;
  bool _tokenModified = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _nameController = TextEditingController(text: a?.name ?? '');
    _urlController = TextEditingController(text: a?.baseUrl ?? '');
    _tokenController = TextEditingController();
    _notesController = TextEditingController(text: a?.notes ?? '');
    _selectedSiteType = a?.siteType ?? SiteType.newApi;
    _selectedAuthType = a?.authType ?? SiteType.newApi.defaultAuthType;
    _enabled = a?.enabled ?? true;

    // Load existing token when editing.
    if (_isEditing) {
      _loadExistingToken();
    } else {
      _tokenLoaded = true;
    }
  }

  Future<void> _loadExistingToken() async {
    final repo = ref.read(accountsRepositoryProvider);
    final result = await repo.getAccessToken(widget.account!.id);
    if (mounted) {
      result.when(
        onSuccess: (token) {
          if (token != null) {
            _tokenController.text = token;
          }
          setState(() => _tokenLoaded = true);
        },
        onFailure: (_) {
          setState(() => _tokenLoaded = true);
        },
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title.
              Text(
                _isEditing ? '编辑账号' : '添加账号',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              // Enabled toggle (above all other fields so the whole form
              // reflects the account state at a glance).
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '启用账号',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Switch(
                    key: const ValueKey('accountEnabledSwitch'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Name.
              TextFormField(
                controller: _nameController,
                enabled: _enabled,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如：My API Hub',
                ),
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),

              // Base URL.
              TextFormField(
                controller: _urlController,
                enabled: _enabled,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.example.com',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: _validateUrl,
              ),
              const SizedBox(height: AppSpacing.md),

              // Site type dropdown.
              DropdownButtonFormField<SiteType>(
                key: ValueKey(_selectedSiteType),
                initialValue: _selectedSiteType,
                decoration: const InputDecoration(labelText: '站点类型'),
                items: SiteType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _enabled
                    ? (type) {
                        if (type != null) {
                          setState(() {
                            _selectedSiteType = type;
                            _selectedAuthType = type.defaultAuthType;
                          });
                        }
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Auth type dropdown.
              DropdownButtonFormField<AuthType>(
                key: ValueKey(_selectedAuthType),
                initialValue: _selectedAuthType,
                decoration: const InputDecoration(labelText: '认证方式'),
                items: AuthType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _enabled
                    ? (type) {
                        if (type != null) {
                          setState(() => _selectedAuthType = type);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Access token.
              TextFormField(
                controller: _tokenController,
                enabled: _enabled,
                decoration: InputDecoration(
                  labelText: '访问令牌',
                  hintText: _selectedAuthType == AuthType.none
                      ? '当前认证方式无需令牌'
                      : '输入 API Token',
                  suffixIcon: _tokenLoaded
                      ? IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: _enabled
                              ? () {
                                  setState(
                                    () => _obscureToken = !_obscureToken,
                                  );
                                }
                              : null,
                        )
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
                obscureText: _obscureToken,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _tokenModified = true,
              ),
              const SizedBox(height: AppSpacing.md),

              // Notes.
              TextFormField(
                controller: _notesController,
                enabled: _enabled,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '可选备注信息',
                ),
                maxLines: 3,
                validator: _validateNotes,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Submit button.
              FilledButton(
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
                    : Text(_isEditing ? '保存' : '添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入账号名称';
    if (value.trim().length > 50) return '名称不能超过50个字符';
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '请输入API地址';
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return '请输入有效的URL（以 http:// 或 https:// 开头）';
    }
    return null;
  }

  String? _validateNotes(String? value) {
    if (value != null && value.length > 200) return '备注不能超过200个字符';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final account = Account(
      id: _isEditing ? widget.account!.id : const Uuid().v4(),
      name: _nameController.text.trim(),
      baseUrl: _urlController.text.trim(),
      siteType: _selectedSiteType,
      authType: _selectedAuthType,
      enabled: _enabled,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      balance: _isEditing ? widget.account!.balance : null,
      createdAt: _isEditing ? widget.account!.createdAt : now,
      updatedAt: now,
    );

    // Determine the access token to pass.
    // If editing and token field was not modified, pass null to preserve
    // the existing stored token. Otherwise pass the current field value.
    String? accessToken;
    if (_isEditing) {
      if (_tokenModified) {
        accessToken = _tokenController.text.isEmpty
            ? ''
            : _tokenController.text;
      }
    } else {
      accessToken = _tokenController.text.isEmpty
          ? null
          : _tokenController.text;
    }

    try {
      final notifier = ref.read(accountsProvider.notifier);
      if (_isEditing) {
        await notifier.saveAccount(account, accessToken: accessToken);
      } else {
        await notifier.create(account, accessToken: accessToken);
      }

      // Re-run reachability check when the account is (or just became) enabled
      // so the list card updates immediately. Fire-and-forget; we don't block
      // the sheet close on a network call.
      final prevEnabled = widget.account?.enabled ?? false;
      final shouldRecheck = _enabled && (!_isEditing || !prevEnabled);
      if (shouldRecheck) {
        unawaited(notifier.checkOne(account.id));
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
