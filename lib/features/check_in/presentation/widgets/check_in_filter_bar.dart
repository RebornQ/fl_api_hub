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
class CheckInFilterBar extends StatelessWidget {
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
              _buildChip(context, '全部 ($totalCount)', null),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '成功 ($successCount)', CheckInStatus.success),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '失败 ($failedCount)', CheckInStatus.failed),
              const SizedBox(width: AppSpacing.sm),
              _buildChip(context, '已跳过 ($skippedCount)', CheckInStatus.skipped),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 4),
        // Search bar.
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '搜索账号名称或消息...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md + AppSpacing.xs,
            ),
          ),
          onChanged: onSearchChanged,
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, String label, CheckInStatus? filter) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = selectedFilter == filter;

    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: () => onFilterChanged(filter),
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
