/// A 2×2 grid displaying quota and date information for an API key.
///
/// Shows: remaining quota, used quota, expiration, and creation date.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../../core/config/app_defaults.dart';
import '../../domain/entities/api_key.dart';

/// Grid of key stats: remaining quota, used quota, expiry, and creation date.
class KeyQuotaGrid extends StatelessWidget {
  final ApiKey apiKey;

  const KeyQuotaGrid({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _cell(context, '剩余额度', _remainingQuota)),
              Expanded(child: _cell(context, '已用额度', _usedQuota)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: _cell(context, '过期时间', _expiresAt)),
              Expanded(child: _cell(context, '创建日期', _createdAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  String get _remainingQuota {
    if (apiKey.quota == null) return '无限额度';
    final remaining = (apiKey.quota! - apiKey.usedQuota) / kDefaultQuotaPerUnit;
    return '\$${remaining.toStringAsFixed(2)}';
  }

  String get _usedQuota =>
      '\$${(apiKey.usedQuota / kDefaultQuotaPerUnit).toStringAsFixed(2)}';

  String get _expiresAt =>
      apiKey.expiresAt != null ? _formatDate(apiKey.expiresAt!) : '永不过期';

  String get _createdAt => _formatDate(apiKey.createdAt);

  /// Formats a [DateTime] as "yyyy/M/d" (e.g. "2026/1/10").
  String _formatDate(DateTime date) => '${date.year}/${date.month}/${date.day}';
}
