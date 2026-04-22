/// Pill-shaped badge that shows the HTTP method of a logged request.
///
/// Colours mirror common REST conventions (GET green, POST blue, PUT amber,
/// DELETE red, PATCH purple, anything else neutral) so the eye can scan a
/// long list quickly. The badge is a pure [StatelessWidget] with no state
/// or callbacks — list tiles place it as a leading element.
library;

import 'package:flutter/material.dart';

/// Small fixed-width pill rendering the HTTP method label.
class RequestLogMethodBadge extends StatelessWidget {
  final String method;

  const RequestLogMethodBadge({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    final upper = method.toUpperCase();
    final (bg, fg) = _colours(upper);
    return Container(
      width: 58,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        upper,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color) _colours(String upper) {
    switch (upper) {
      case 'GET':
        return (const Color(0xFFD1FAE5), const Color(0xFF047857));
      case 'POST':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      case 'PUT':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'DELETE':
        return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      case 'PATCH':
        return (const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
      default:
        return (const Color(0xFFE5E7EB), const Color(0xFF374151));
    }
  }
}
