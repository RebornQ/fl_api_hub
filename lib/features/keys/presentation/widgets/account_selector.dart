/// Searchable account dropdown selector for the Keys feature.
///
/// Displays a styled dropdown that lets the user pick which account's
/// API keys to view, with an integrated search field for filtering
/// accounts by name (case-insensitive contains).
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../accounts/domain/entities/account.dart';

/// A searchable dropdown for selecting an account to view its keys.
///
/// Uses an overlay-based popup with a search TextField at the top and
/// a scrollable filtered list below. The public API is identical to the
/// previous [DropdownButtonFormField]-based version so callers need no
/// changes.
class AccountSelector extends StatefulWidget {
  /// All available accounts.
  final List<Account> accounts;

  /// Currently selected account ID.
  final String? selectedId;

  /// Callback when the user picks a different account.
  final ValueChanged<String?> onChanged;

  const AccountSelector({
    super.key,
    required this.accounts,
    this.selectedId,
    required this.onChanged,
  });

  @override
  State<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends State<AccountSelector> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _isOpen => _overlayEntry != null;

  bool get _isDisabled => widget.accounts.isEmpty;

  /// Returns the currently selected account, or null.
  Account? get _selectedAccount {
    if (widget.selectedId == null) return null;
    return widget.accounts.where((a) => a.id == widget.selectedId).firstOrNull;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _closeOverlay();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    if (_isDisabled) return;

    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    final theme = Theme.of(context);

    _searchController.clear();
    _searchQuery = '';

    _overlayEntry = OverlayEntry(
      builder: (context) => _AccountSelectorOverlay(
        layerLink: _layerLink,
        anchorWidth: size.width,
        theme: theme,
        searchController: _searchController,
        onSearchChanged: (query) {
          _searchQuery = query;
          _overlayEntry?.markNeedsBuild();
        },
        accounts: widget.accounts,
        searchQuery: _searchQuery,
        selectedId: widget.selectedId,
        onSelected: (id) {
          widget.onChanged(id);
          _closeOverlay();
        },
        onDismiss: _closeOverlay,
      ),
    );

    overlay.insert(_overlayEntry!);
    setState(() {});
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _searchController.clear();
    _searchQuery = '';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _selectedAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择账号',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        CompositedTransformTarget(
          link: _layerLink,
          child: Material(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              onTap: _isDisabled ? null : _toggleOverlay,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InputDecorator(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  suffixIcon: Icon(
                    _isOpen ? Icons.expand_less : Icons.unfold_more,
                    color: colorScheme.outline,
                  ),
                ),
                child: Text(
                  selected?.name ?? (_isDisabled ? '请先添加账号' : '请选择账号'),
                  style: TextStyle(
                    color: selected != null
                        ? colorScheme.onSurface
                        : (_isDisabled
                              ? colorScheme.outline
                              : colorScheme.onSurfaceVariant),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The overlay popup shown when the selector is open.
///
/// Contains a search TextField at the top and a scrollable list of
/// filtered accounts below. Tapping outside dismisses the overlay.
class _AccountSelectorOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final double anchorWidth;
  final ThemeData theme;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<Account> accounts;
  final String searchQuery;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;

  const _AccountSelectorOverlay({
    required this.layerLink,
    required this.anchorWidth,
    required this.theme,
    required this.searchController,
    required this.onSearchChanged,
    required this.accounts,
    required this.searchQuery,
    required this.selectedId,
    required this.onSelected,
    required this.onDismiss,
  });

  List<Account> get _filtered {
    if (searchQuery.isEmpty) return accounts;
    final q = searchQuery.toLowerCase();
    return accounts.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final filtered = _filtered;

    return Stack(
      children: [
        // Dismiss barrier.
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Popup content.
        CompositedTransformFollower(
          link: layerLink,
          offset: const Offset(0, 4),
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: anchorWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search field.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      0,
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        // TODO: 当前实现会报错, 待修复
                        // suffixIcon: searchQuery.isNotEmpty
                        //     ? IconButton(
                        //         tooltip: '清除',
                        //         icon: const Icon(Icons.close, size: 18),
                        //         onPressed: () {
                        //           searchController.clear();
                        //           onSearchChanged('');
                        //         },
                        //       )
                        //     : null,
                        hintText: '搜索账号...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Account list.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xl,
                            ),
                            child: Text(
                              '没有匹配的账号',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final account = filtered[index];
                              final isSelected = account.id == selectedId;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                                leading: Icon(
                                  account.enabled
                                      ? Icons.cloud_outlined
                                      : Icons.cloud_off_outlined,
                                  size: 20,
                                  color: account.enabled
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                ),
                                title: Text(
                                  account.name,
                                  style: TextStyle(
                                    color: account.enabled
                                        ? colorScheme.onSurface
                                        : colorScheme.outline,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 18,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                                onTap: () => onSelected(account.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
