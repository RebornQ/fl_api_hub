/// Status badge chip displayed on a key card.
///
/// Shows "启用" (green) for active keys and "已过期" (red) for expired ones.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/api_key.dart';

/// A small pill-shaped badge indicating key status.
class KeyStatusBadge extends StatelessWidget {
  final ApiKey apiKey;

  const KeyStatusBadge({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    final isExpired = apiKey.isExpired;
    final backgroundColor = isExpired
        ? Theme.of(context).colorScheme.errorContainer
        : const Color(0xFFD1FAE5); // emerald-100
    final textColor = isExpired
        ? Theme.of(context).colorScheme.onErrorContainer
        : const Color(0xFF047857); // emerald-700
    final label = isExpired ? '已过期' : '启用';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
