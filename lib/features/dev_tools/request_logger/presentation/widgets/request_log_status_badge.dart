/// Pill-shaped badge showing the HTTP status code (or `ERR` for transport
/// failures) with colour coded by response class.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/request_log_entry.dart';

/// Colour-coded status badge driven by [RequestLogEntry.statusCode].
class RequestLogStatusBadge extends StatelessWidget {
  final int? statusCode;

  const RequestLogStatusBadge({super.key, required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _style(statusCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color, String) _style(int? code) {
    if (code == null) {
      return (const Color(0xFFE5E7EB), const Color(0xFF374151), 'ERR');
    }
    if (code >= 200 && code < 300) {
      return (const Color(0xFFD1FAE5), const Color(0xFF047857), '$code');
    }
    if (code >= 300 && code < 400) {
      return (const Color(0xFFE0F2FE), const Color(0xFF0369A1), '$code');
    }
    if (code >= 400 && code < 500) {
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309), '$code');
    }
    if (code >= 500 && code < 600) {
      return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C), '$code');
    }
    return (const Color(0xFFE5E7EB), const Color(0xFF374151), '$code');
  }
}
