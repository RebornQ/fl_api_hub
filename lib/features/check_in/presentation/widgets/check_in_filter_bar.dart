/// Filter chips and search bar for the check-in results dashboard.
///
/// Displays horizontal scrollable chips for status filtering (全部/成功/失败/已跳过)
/// with counts, and a search field for account name or message search.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/check_in_result.dart';

/// Callback type for filter and search changes.
typedef CheckInFilterCallback =
    void Function(CheckInStatus? filter, String searchQuery);

/// Combined filter chips + search bar widget.
class CheckInFilterBar extends StatefulWidget {
  final CheckInStatus? selectedFilter;
  final String searchQuery;
  final int totalCount;
  final int successCount;
  final int failedCount;
  final int skippedCount;
  final ValueChanged<CheckInStatus?> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  const CheckInFilterBar({
    super.key,
    required this.selectedFilter,
    required this.searchQuery,
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.skippedCount,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  @override
  State<CheckInFilterBar> createState() => _CheckInFilterBarState();
}

class _CheckInFilterBarState extends State<CheckInFilterBar> {
  final _searchController = TextEditingController();
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Filter chips.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildChip(context, '全部 (${widget.totalCount})', null),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '成功 (${widget.successCount})', CheckInStatus.success),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '失败 (${widget.failedCount})', CheckInStatus.failed),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '已跳过 (${widget.skippedCount})', CheckInStatus.skipped),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        // Search bar.
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _hasSearchText
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    ),
                  )
                : null,
            hintText: '搜索账号名称或消息...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
          ),
          onChanged: widget.onSearchChanged,
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, CheckInStatus? filter) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = widget.selectedFilter == filter;

    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: () => widget.onFilterChanged(filter),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
