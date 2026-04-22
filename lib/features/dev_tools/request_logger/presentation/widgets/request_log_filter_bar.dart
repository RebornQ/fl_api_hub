/// Filter controls for the request logger list page.
///
/// Renders a search `TextField` bound to [RequestLogFilter.keyword] and a
/// horizontally scrollable row of bucket chips (全部 / 2xx / 4xx / 5xx /
/// 错误) whose counts come from the live buffer. Tapping a chip updates
/// [RequestLogFilter.statusBucket]; typing updates [RequestLogFilter.keyword].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../domain/entities/request_log_entry.dart';
import '../../domain/entities/status_bucket.dart';
import '../providers/request_logger_providers.dart';

class RequestLogFilterBar extends ConsumerStatefulWidget {
  const RequestLogFilterBar({super.key});

  @override
  ConsumerState<RequestLogFilterBar> createState() =>
      _RequestLogFilterBarState();
}

class _RequestLogFilterBarState extends ConsumerState<RequestLogFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final keyword = ref.read(requestLogFilterProvider).keyword;
    _controller = TextEditingController(text: keyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = ref.watch(requestLogBufferProvider);
    final filter = ref.watch(requestLogFilterProvider);
    final counts = _counts(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: '搜索 URL（包含即匹配）',
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 4,
            ),
            suffixIcon: filter.keyword.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '清除搜索',
                    onPressed: () {
                      _controller.clear();
                      _updateKeyword('');
                    },
                  ),
          ),
          onChanged: _updateKeyword,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _BucketChip(
                label: '全部 (${counts.all})',
                selected: filter.statusBucket == StatusBucket.all,
                onTap: () => _updateBucket(StatusBucket.all),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BucketChip(
                label: '2xx (${counts.success})',
                selected: filter.statusBucket == StatusBucket.success,
                onTap: () => _updateBucket(StatusBucket.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BucketChip(
                label: '4xx (${counts.client})',
                selected: filter.statusBucket == StatusBucket.clientError,
                onTap: () => _updateBucket(StatusBucket.clientError),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BucketChip(
                label: '5xx (${counts.server})',
                selected: filter.statusBucket == StatusBucket.serverError,
                onTap: () => _updateBucket(StatusBucket.serverError),
              ),
              const SizedBox(width: AppSpacing.sm),
              _BucketChip(
                label: '错误 (${counts.error})',
                selected: filter.statusBucket == StatusBucket.error,
                onTap: () => _updateBucket(StatusBucket.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateKeyword(String value) {
    final current = ref.read(requestLogFilterProvider);
    ref.read(requestLogFilterProvider.notifier).state = current.copyWith(
      keyword: value,
    );
  }

  void _updateBucket(StatusBucket bucket) {
    final current = ref.read(requestLogFilterProvider);
    ref.read(requestLogFilterProvider.notifier).state = current.copyWith(
      statusBucket: bucket,
    );
  }

  _BucketCounts _counts(List<RequestLogEntry> entries) {
    var success = 0;
    var client = 0;
    var server = 0;
    var error = 0;
    for (final e in entries) {
      if (e.isSuccess) {
        success++;
      } else if (e.isClientError) {
        client++;
      } else if (e.isServerError) {
        server++;
      } else if (e.isError) {
        error++;
      }
    }
    return _BucketCounts(
      all: entries.length,
      success: success,
      client: client,
      server: server,
      error: error,
    );
  }
}

class _BucketCounts {
  final int all;
  final int success;
  final int client;
  final int server;
  final int error;

  const _BucketCounts({
    required this.all,
    required this.success,
    required this.client,
    required this.server,
    required this.error,
  });
}

class _BucketChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BucketChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9999),
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
