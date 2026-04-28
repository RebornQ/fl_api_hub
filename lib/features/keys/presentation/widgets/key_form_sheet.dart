/// Modal bottom sheet form for adding or editing an [ApiKey].
///
/// When [apiKey] is `null`, the form operates in add mode. Otherwise it
/// pre-populates fields from the given key.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../../core/config/app_defaults.dart';
import '../../../../core/network/dto/group_dto.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../domain/entities/api_key.dart';
import '../providers/groups_providers.dart';
import '../providers/keys_providers.dart';

/// A bottom-sheet form for creating or editing an API key.
class KeyFormSheet extends ConsumerStatefulWidget {
  /// Existing key for edit mode; `null` for add mode.
  final ApiKey? apiKey;

  /// Account ID to pre-select (used in add mode).
  final String? accountId;

  const KeyFormSheet({super.key, this.apiKey, this.accountId});

  /// Opens the form as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    ApiKey? apiKey,
    String? accountId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => KeyFormSheet(apiKey: apiKey, accountId: accountId),
    );
  }

  @override
  ConsumerState<KeyFormSheet> createState() => _KeyFormSheetState();
}

class _KeyFormSheetState extends ConsumerState<KeyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quotaController;
  late final TextEditingController _expiresAtController;

  String? _selectedAccountId;
  DateTime? _selectedExpiry;
  String? _selectedGroup;
  bool _isSubmitting = false;

  bool get _isEditing => widget.apiKey != null;

  @override
  void initState() {
    super.initState();
    final k = widget.apiKey;
    _nameController = TextEditingController(text: k?.name ?? '');
    _quotaController = TextEditingController(
      text: k?.quota != null
          ? (k!.quota! / kDefaultQuotaPerUnit).toStringAsFixed(2)
          : '',
    );
    _expiresAtController = TextEditingController();
    _selectedAccountId = k?.accountId ?? widget.accountId;
    _selectedExpiry = k?.expiresAt;
    _selectedGroup = k?.group;

    if (_selectedExpiry != null) {
      _expiresAtController.text = _formatDate(_selectedExpiry!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quotaController.dispose();
    _expiresAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final groupsAsync = _selectedAccountId != null
        ? ref.watch(groupsProvider(_selectedAccountId!))
        : const AsyncValue<List<GroupDto>>.data([]);

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
                _isEditing ? '编辑密钥' : '添加密钥',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),

              // Account selector (locked in edit mode).
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                decoration: const InputDecoration(labelText: '所属账号'),
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: _isEditing
                    ? null
                    : (id) => setState(() {
                        _selectedAccountId = id;
                        _selectedGroup = null;
                      }),
                validator: (value) => value == null ? '请选择账号' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Key name.
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '密钥名称',
                  hintText: '例如：Gemini',
                ),
                textInputAction: TextInputAction.next,
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),

              // Quota (optional, in USD).
              TextFormField(
                controller: _quotaController,
                decoration: const InputDecoration(
                  labelText: '额度限制 (\$)',
                  hintText: '留空表示无限制',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                validator: _validateQuota,
              ),
              const SizedBox(height: AppSpacing.md),

              // Expiration date (optional).
              TextFormField(
                controller: _expiresAtController,
                decoration: InputDecoration(
                  labelText: '过期时间',
                  hintText: '永不过期',
                  suffixIcon: _selectedExpiry != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedExpiry = null;
                              _expiresAtController.clear();
                            });
                          },
                        )
                      : null,
                ),
                readOnly: true,
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.md),

              // Group selector (optional).
              groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    // No groups available (e.g. Octopus or network error).
                    return const SizedBox.shrink();
                  }
                  // Deduplicate by name and sort alphabetically.
                  final uniqueNames = <String>{for (final g in groups) g.name};
                  final sortedNames = uniqueNames.toList()..sort();
                  // Sync _selectedGroup with API: reset to null if not in list.
                  final effectiveGroup =
                      _selectedGroup != null &&
                          sortedNames.contains(_selectedGroup)
                      ? _selectedGroup
                      : null;
                  return Column(
                    children: [
                      DropdownButtonFormField<String?>(
                        initialValue: effectiveGroup,
                        decoration: const InputDecoration(
                          labelText: '分组',
                          hintText: '默认（不指定）',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('默认（不指定）'),
                          ),
                          ...sortedNames.map(
                            (name) => DropdownMenuItem<String?>(
                              value: name,
                              child: Text(name),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedGroup = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  );
                },
                loading: () => Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: null,
                      decoration: const InputDecoration(labelText: '分组'),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('分组加载中，请稍候...'),
                        ),
                      ],
                      onChanged: null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
                error: (_, _) => const SizedBox.shrink(),
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
    if (value == null || value.trim().isEmpty) return '请输入密钥名称';
    if (value.trim().length > 50) return '名称不能超过50个字符';
    return null;
  }

  String? _validateQuota(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return '请输入有效的数字';
    if (parsed <= 0) return '额度必须大于0';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Date picker
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedExpiry ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _selectedExpiry = picked;
        _expiresAtController.text = _formatDate(picked);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Submission
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) return;

    setState(() => _isSubmitting = true);

    final now = DateTime.now();
    final quotaText = _quotaController.text.trim();
    final int? rawQuota;
    if (quotaText.isNotEmpty) {
      rawQuota = (double.parse(quotaText) * kDefaultQuotaPerUnit).round();
    } else {
      rawQuota = null;
    }

    final apiKey = ApiKey(
      id: _isEditing ? widget.apiKey!.id : const Uuid().v4(),
      accountId: _selectedAccountId!,
      name: _nameController.text.trim(),
      keyValue: _isEditing ? widget.apiKey!.keyValue : null,
      quota: rawQuota,
      usedQuota: _isEditing ? widget.apiKey!.usedQuota : 0,
      expiresAt: _selectedExpiry,
      createdAt: _isEditing ? widget.apiKey!.createdAt : now,
      updatedAt: now,
      group: _selectedGroup,
    );

    try {
      final notifier = ref.read(keysProvider(_selectedAccountId!).notifier);
      if (_isEditing) {
        await notifier.saveKey(apiKey);
      } else {
        await notifier.create(apiKey);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '密钥更新成功' : '密钥添加成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Formats a [DateTime] as "yyyy/M/d".
  static String _formatDate(DateTime date) =>
      '${date.year}/${date.month}/${date.day}';
}
