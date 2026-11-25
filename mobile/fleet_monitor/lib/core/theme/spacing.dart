import 'package:flutter/painting.dart';

/// 4 px base. Screen padding 16, card padding 14/16, list gap 8 (Tokens.dc.html).
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Minimum tap target.
  static const tap = 48.0;
}

abstract final class AppRadius {
  static const mapTag = 4.0;
  static const badge = 6.0;
  static const chip = 8.0; // also large badge
  static const input = 10.0; // also small buttons
  static const card = 12.0; // also tiles, primary buttons
  static const sheet = 16.0;
}

/// Flat by default: outlines separate surfaces. Shadows only for things floating over the map / the sheet.
abstract final class AppShadows {
  static const level1 = [
    BoxShadow(color: Color(0x1F111827), offset: Offset(0, 1), blurRadius: 3),
  ];
  static const level2 = [
    BoxShadow(color: Color(0x2E111827), offset: Offset(0, 2), blurRadius: 6),
  ];
  static const level3 = [
    BoxShadow(color: Color(0x2E111827), offset: Offset(0, -4), blurRadius: 16),
  ];
}
