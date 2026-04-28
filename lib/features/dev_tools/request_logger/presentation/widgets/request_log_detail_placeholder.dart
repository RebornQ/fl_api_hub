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
/// An AppBar toggle button allows showing/hiding sensitive header values
/// (Authorization, Cookie, etc.). By default, sensitive values are masked.
///
/// When [entry] is `null`, displays a centered placeholder message for the
/// wide-layout empty state ("选择左侧的请求以查看详情").
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/section_card.dart';
import '../../data/utils/curl_exporter.dart';
import '../../data/utils/header_redactor.dart';
import '../../domain/entities/request_log_entry.dart';
import '../utils/code_highlighter.dart';

/// Case-insensitive header lookup.
///
/// Dio stores response headers in lowercase, but request headers retain
/// their original casing (e.g. 'Content-Type'). This helper normalises the
/// lookup so language detection works regardless of key casing.
String? _headerValue(Map<String, dynamic> headers, String key) {
  final lowerKey = key.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lowerKey) {
      return entry.value?.toString();
    }
  }
  return null;
}

class RequestLogDetailView extends StatefulWidget {
  final RequestLogEntry? entry;

  const RequestLogDetailView({super.key, this.entry});

  @override
  State<RequestLogDetailView> createState() => _RequestLogDetailViewState();
}

class _RequestLogDetailViewState extends State<RequestLogDetailView> {
  bool _showSensitive = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
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
            120, // Space for two FABs (mini + extended).
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewCard(entry: e),
              const SizedBox(height: AppSpacing.md),
              _RequestCard(entry: e, showSensitive: _showSensitive),
              const SizedBox(height: AppSpacing.md),
              _ResponseCard(entry: e),
            ],
          ),
        ),
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'toggle_sensitive',
                mini: true,
                onPressed: () =>
                    setState(() => _showSensitive = !_showSensitive),
                tooltip: _showSensitive ? '隐藏敏感信息' : '显示敏感信息',
                child: Icon(
                  _showSensitive ? Icons.visibility : Icons.visibility_off,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FloatingActionButton.extended(
                heroTag: 'copy_curl',
                onPressed: () => _copyCurl(context, e),
                icon: const Icon(Icons.content_copy),
                label: const Text('Copy as curl'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyCurl(BuildContext context, RequestLogEntry entry) async {
    final curl = exportAsCurl(entry);
    await Clipboard.setData(ClipboardData(text: curl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制 curl 命令到剪贴板')));
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
          _InfoRow(label: '耗时', value: _formatElapsed(entry.elapsed)),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(label: '开始', value: _formatTime(entry.startedAt)),
          if (entry.endedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(label: '结束', value: _formatTime(entry.endedAt!)),
          ],
          if (entry.correlationId != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(label: '关联ID', value: entry.correlationId!),
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
  final bool showSensitive;

  const _RequestCard({required this.entry, required this.showSensitive});

  @override
  Widget build(BuildContext context) {
    // Redact sensitive headers unless user explicitly enables showing them.
    final displayHeaders = showSensitive
        ? entry.requestHeaders
        : redactHeaders(entry.requestHeaders);

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
          _KeyValueTable(data: displayHeaders),
          const SizedBox(height: AppSpacing.md),
          _SectionLabel('请求体'),
          const SizedBox(height: AppSpacing.xs),
          _CollapsibleBody(
            body: entry.requestBody,
            contentType: _headerValue(entry.requestHeaders, 'content-type'),
          ),
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
            contentType: _headerValue(entry.responseHeaders, 'content-type'),
            emptyPlaceholder: entry.isError ? '<请求失败，无响应>' : '<无响应体>',
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

  const _InfoRow({required this.label, required this.value, this.valueColor});

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
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
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
  final String? contentType;
  final String emptyPlaceholder;

  const _CollapsibleBody({
    this.body,
    this.contentType,
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

    // Determine if toggle is needed:
    // 1. More than 10 newline characters (obvious multi-line content)
    // 2. OR very long single-line content that will be visually truncated by maxLines
    //    (estimate: 10 lines * ~80 chars per line in monospace at typical width)
    final lineCount = '\n'.allMatches(body).length + 1;
    final estimatedVisualLines = (body.length / 80).ceil();
    final needsToggle = lineCount > 10 || estimatedVisualLines > 10;

    // When expanded, show full text with "收起" button at the end
    if (_isExpanded) {
      final baseStyle = theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        height: 1.4,
      );
      final isDark = theme.brightness == Brightness.dark;

      // Determine language and format body.
      final language = detectLanguage(widget.contentType, body);
      final displayBody = language == 'json' ? prettyPrintJson(body) : body;
      final span = buildHighlightedSpan(
        body: displayBody,
        language: language,
        baseStyle:
            baseStyle ?? const TextStyle(fontFamily: 'monospace', height: 1.4),
        isDark: isDark,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText.rich(span),
          if (needsToggle) ...[
            const SizedBox(height: AppSpacing.xs),
            GestureDetector(
              onTap: () => setState(() => _isExpanded = false),
              child: Text(
                '收起',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // When collapsed, use LayoutBuilder to measure available width and
    // create a RichText with "...展开" embedded at the end
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.4,
    );

    if (!needsToggle) {
      final isDark = theme.brightness == Brightness.dark;
      final language = detectLanguage(widget.contentType, body);
      final displayBody = language == 'json' ? prettyPrintJson(body) : body;
      final span = buildHighlightedSpan(
        body: displayBody,
        language: language,
        baseStyle:
            baseStyle ?? const TextStyle(fontFamily: 'monospace', height: 1.4),
        isDark: isDark,
      );
      return SelectableText.rich(span);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite) {
          // Fallback if no width constraint
          return _buildCollapsedWithButton(body, baseStyle!, theme);
        }

        return _buildCollapsedRichText(body, baseStyle!, theme, maxWidth);
      },
    );
  }

  /// Fallback: show text with button below (original behavior)
  Widget _buildCollapsedWithButton(
    String body,
    TextStyle baseStyle,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: baseStyle,
          maxLines: 10,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = true),
          child: Text(
            '展开',
            style: baseStyle.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build RichText with "...展开" embedded at the truncation point
  Widget _buildCollapsedRichText(
    String body,
    TextStyle baseStyle,
    ThemeData theme,
    double maxWidth,
  ) {
    const int maxLines = 10;
    const String ellipsis = '...';
    const String expandText = '展开';

    // Use TextPainter to find where to truncate
    final painter = TextPainter(
      text: TextSpan(text: body, style: baseStyle),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    );

    painter.layout(maxWidth: maxWidth);

    // Check if text visually exceeds maxLines
    // Use TextPainter's didExceedMaxLines for accurate visual measurement
    if (!painter.didExceedMaxLines) {
      // Text fits within maxLines, no truncation needed
      return SelectableText(body, style: baseStyle);
    }

    // Calculate space needed for "...展开"
    final expandStyle = baseStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );

    final suffixPainter = TextPainter(
      text: TextSpan(text: '$ellipsis$expandText', style: baseStyle),
      textDirection: TextDirection.ltr,
    );
    suffixPainter.layout();
    final suffixWidth = suffixPainter.width;

    // Get the last line's metrics for truncation calculation
    final lastLineMetrics = painter.computeLineMetrics();
    final availableWidthForText = lastLineMetrics.isNotEmpty
        ? lastLineMetrics.last.width - suffixWidth
        : maxWidth - suffixWidth;

    // Binary search to find the character position that fits
    int truncatePos = _findTruncatePosition(
      body,
      baseStyle,
      maxWidth,
      maxLines,
      availableWidthForText,
    );

    // Build the RichText with truncated text + "...展开"
    final truncatedText = body.substring(0, truncatePos);

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = true),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: truncatedText, style: baseStyle),
            TextSpan(text: ellipsis, style: baseStyle),
            TextSpan(text: expandText, style: expandStyle),
          ],
        ),
        maxLines: maxLines,
      ),
    );
  }

  /// Binary search to find the optimal truncation position
  int _findTruncatePosition(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
    double availableWidthForLastLine,
  ) {
    int left = 0;
    int right = text.length;
    int bestPos = text.length;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final testText = text.substring(0, mid);

      final painter = TextPainter(
        text: TextSpan(text: testText, style: style),
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
      );
      painter.layout(maxWidth: maxWidth);

      final lineMetrics = painter.computeLineMetrics();
      if (lineMetrics.isEmpty) {
        left = mid + 1;
        continue;
      }

      final lastLineWidth = lineMetrics.last.width;
      final exceeded =
          painter.didExceedMaxLines ||
          lastLineWidth > availableWidthForLastLine + 5;

      if (exceeded) {
        right = mid - 1;
      } else {
        bestPos = mid;
        left = mid + 1;
      }
    }

    return bestPos;
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
        border: Border.all(color: colorScheme.error.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: colorScheme.error),
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
