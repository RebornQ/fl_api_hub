/// Detail view for a single captured request log entry.
///
/// Renders three grouped sections (概览 / Request / Response) using
/// [SectionCard] from `core/widgets/`. Each section displays relevant
/// fields from the [RequestLogEntry] with appropriate formatting:
/// - 概览: method, URL, status, elapsed, timestamps.
/// - Request: query params, headers, body (collapsible if > 10 lines).
/// - Response: headers, body (collapsible), error info (if present).
///
/// A floating "Copy as curl" button exports the entry via [exportAsCurl]
/// and copies the result to the system clipboard, showing a confirmation
/// [SnackBar].
///
/// When [entry] is `null`, displays a centered placeholder message for the
/// wide-layout empty state ("选择左侧的请求以查看详情").
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../data/utils/curl_exporter.dart';
import '../../domain/entities/request_log_entry.dart';

class RequestLogDetailView extends StatelessWidget {
  final RequestLogEntry? entry;

  const RequestLogDetailView({super.key, this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    if (e == null) {
      return Center(
        child: Text(
          '选择左侧的请求以查看详情',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            80, // Space for FAB.
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewCard(entry: e),
              const SizedBox(height: AppSpacing.md),
              _RequestCard(entry: e),
              const SizedBox(height: AppSpacing.md),
              _ResponseCard(entry: e),
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: FloatingActionButton.extended(
            onPressed: () => _copyCurl(context, e),
            icon: const Icon(Icons.content_copy),
            label: const Text('Copy as curl'),
          ),
        ),
      ],
    );
  }

  Future<void> _copyCurl(BuildContext context, RequestLogEntry entry) async {
    final curl = exportAsCurl(entry);
    await Clipboard.setData(ClipboardData(text: curl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制 curl 命令到剪贴板')),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final RequestLogEntry entry;
  const _OverviewCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SectionCard(
      icon: Icons.info_outline,
      title: '概览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.method} ${entry.url}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '状态',
            value: _statusLabel(entry),
            valueColor: _statusColor(entry, colorScheme),
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            label: '耗时',
            value: _formatElapsed(entry.elapsed),
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            label: '开始',
            value: _formatTime(entry.startedAt),
          ),
          if (entry.endedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              label: '结束',
              value: _formatTime(entry.endedAt!),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(RequestLogEntry e) {
    final code = e.statusCode;
    if (code == null) return 'ERR ${e.errorType ?? 'Unknown'}';
    return '$code ${_httpStatusText(code)}';
  }

  String _httpStatusText(int code) {
    if (code == 200) return 'OK';
    if (code == 201) return 'Created';
    if (code == 204) return 'No Content';
    if (code == 400) return 'Bad Request';
    if (code == 401) return 'Unauthorized';
    if (code == 403) return 'Forbidden';
    if (code == 404) return 'Not Found';
    if (code == 500) return 'Internal Server Error';
    if (code == 502) return 'Bad Gateway';
    if (code == 503) return 'Service Unavailable';
    return '';
  }

  Color _statusColor(RequestLogEntry e, ColorScheme cs) {
    if (e.isSuccess) return const Color(0xFF047857);
    if (e.isClientError) return const Color(0xFFB45309);
    if (e.isServerError) return const Color(0xFFB91C1C);
    return cs.onSurfaceVariant;
  }

  String _formatElapsed(Duration? d) {
    if (d == null) return '--';
    if (d.inMilliseconds < 1) return '<1 ms';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds} ms';
    return '${(d.inMilliseconds / 1000).toStringAsFixed(2)} s';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}.'
        '${dt.millisecond.toString().padLeft(3, '0')}';
  }
}

class _RequestCard extends StatelessWidget {
  final RequestLogEntry entry;
  const _RequestCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.upload_outlined,
      title: 'Request',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.query.isNotEmpty) ...[
            _SectionLabel('Query 参数'),
            const SizedBox(height: AppSpacing.xs),
            _KeyValueTable(data: entry.query),
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionLabel('请求头'),
          const SizedBox(height: AppSpacing.xs),
          _KeyValueTable(data: entry.requestHeaders),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel('请求体'),
          const SizedBox(height: AppSpacing.xs),
          _CollapsibleBody(body: entry.requestBody),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final RequestLogEntry entry;
  const _ResponseCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasError = entry.errorType != null;
    return SectionCard(
      icon: Icons.download_outlined,
      title: 'Response',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.responseHeaders.isNotEmpty) ...[
            _SectionLabel('响应头'),
            const SizedBox(height: AppSpacing.xs),
            _KeyValueTable(data: entry.responseHeaders),
            const SizedBox(height: AppSpacing.md),
          ],
          _SectionLabel('响应体'),
          const SizedBox(height: AppSpacing.xs),
          _CollapsibleBody(
            body: entry.responseBody,
            emptyPlaceholder:
                entry.isError ? '<请求失败，无响应>' : '<无响应体>',
          ),
          if (hasError) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorSection(entry: entry),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _KeyValueTable extends StatelessWidget {
  final Map<String, dynamic> data;
  const _KeyValueTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Text(
        '<空>',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: data.entries.map((e) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                right: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                e.key,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                e.value.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _CollapsibleBody extends StatefulWidget {
  final String? body;
  final String emptyPlaceholder;

  const _CollapsibleBody({
    this.body,
    this.emptyPlaceholder = '<无请求体>',
  });

  @override
  State<_CollapsibleBody> createState() => _CollapsibleBodyState();
}

class _CollapsibleBodyState extends State<_CollapsibleBody> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = widget.body;

    if (body == null || body.isEmpty) {
      return Text(
        widget.emptyPlaceholder,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final lineCount = '\n'.allMatches(body).length + 1;
    final needsToggle = lineCount > 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
          ),
          maxLines: _isExpanded ? null : 10,
          overflow: _isExpanded ? null : TextOverflow.ellipsis,
        ),
        if (needsToggle) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_isExpanded ? '收起' : '展开'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorSection extends StatelessWidget {
  final RequestLogEntry entry;
  const _ErrorSection({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: colorScheme.error.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 16,
                color: colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '错误信息',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Type: ${entry.errorType}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: colorScheme.onErrorContainer,
            ),
          ),
          if (entry.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
