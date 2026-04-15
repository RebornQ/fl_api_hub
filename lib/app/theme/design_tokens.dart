import 'package:flutter/material.dart';

/// Design tokens from DESIGN.md / Stitch design system.
///
/// All color, spacing, and radius constants live here so that every widget
/// references a single source of truth.
///
/// Primary:   #6750a4 (brand / CTAs)
/// Secondary: #625b71 (secondary elements)
/// Tertiary:  #7d5260 (accents / highlights)
/// Neutral:   #79747e (backgrounds / surfaces)
abstract final class AppColors {
  static const primary = Color(0xFF6750A4);
  static const secondary = Color(0xFF625B71);
  static const tertiary = Color(0xFF7D5260);
  static const neutral = Color(0xFF79747E);
}

/// Spacing scale (4 px base unit).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Border radius scale.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
}
