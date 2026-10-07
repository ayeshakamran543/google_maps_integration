import 'package:flutter/material.dart';

/// CampusRide palette: deep indigo ink, violet accent, and one vivid color per
/// shuttle line.
class AppColors {
  static const ink = Color(0xFF1B1F3B);
  static const inkSoft = Color(0xFF6B7092);
  static const violet = Color(0xFF6C5CE7);
  static const violetSoft = Color(0xFFEDEAFF);
  static const surface = Colors.white;
  static const canvas = Color(0xFFF5F6FB);
  static const hairline = Color(0xFFE6E8F2);

  static const coral = Color(0xFFF2545B);
  static const sky = Color(0xFF3D7BFF);
  static const mint = Color(0xFF16B88A);
  static const amber = Color(0xFFFFA62B);

  static const warning = Color(0xFFE5484D);
  static const warningSoft = Color(0xFFFFE9EA);

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
