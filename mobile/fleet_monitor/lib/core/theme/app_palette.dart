import 'package:flutter/painting.dart';

/// Every colour from docs/design (Tokens.dc.html + component sheets). Widgets use these or the ColorScheme;
/// no other hex values appear in the UI code.
abstract final class AppPalette {
  // Core → ColorScheme
  static const primary = Color(
    0xFF1E293B,
  ); // ink: buttons, selected chip (14.6:1)
  static const primaryBusy = Color(0xFF475569); // primary button while loading
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDDE3EA); // navigation indicator
  static const surface = Color(0xFFFFFFFF); // cards, app bar, sheets
  static const background = Color(0xFFF4F5F2); // scaffold (surfaceContainerLow)
  static const muted = Color(
    0xFFEEF0F2,
  ); // stale/offline card (surfaceContainerHighest)
  static const mutedBorder = Color(0xFFC9CED4);
  static const skeleton = Color(0xFFE1E4E8);
  static const onSurface = Color(0xFF111827); // primary text (17.7:1)
  static const textStrong = Color(0xFF1F2937); // chip and label text
  static const textMuted = Color(
    0xFF374151,
  ); // muted card name, secondary emphasis
  static const onSurfaceVariant = Color(0xFF4B5563); // secondary text (7.6:1)
  static const placeholder = Color(0xFF6B7280); // "—" in empty tiles
  static const hint = Color(
    0xFF9CA3AF,
  ); // compass ring, sheet handle, dashed placeholder
  static const outline = Color(0xFF8A929C); // inputs, chips (3.2:1)
  static const outlineVariant = Color(0xFFD5D9DE); // card borders, dividers
  static const divider = Color(0xFFE5E7EB); // rows, battery track
  static const emptyIconBackground = Color(0xFFE5E8EC);
  static const fleetIconBackground = Color(0xFFECEEF1);

  // Error / warning
  static const error = Color(0xFFB91C1C); // errors, low battery (6.5:1)
  static const onErrorContainer = Color(0xFF8F1414);
  static const errorContainer = Color(0xFFFDE7E7);
  static const errorBorder = Color(0xFFE9A8A8); // fault card, low battery tile
  static const errorTrack = Color(0xFFF5C2C2); // low battery bar track
  static const warningContainer = Color(
    0xFFFDF3DC,
  ); // reconnecting banner, session expired
  static const onWarningContainer = Color(0xFF5C3600);
  static const warningBorder = Color(0xFFE8C77A);
  static const inverseSurface = Color(0xFF1F2937); // disconnected banner
  static const onInverseVariant = Color(0xFFD1D5DB);
  static const disabledButton = Color(0xFFD5D9DE); // rate-limited button
  static const onDisabledButton = Color(0xFF374151);

  // Stale outlines
  static const staleCardBorder = Color(0xFF9F8BD6); // dashed card outline
  static const staleBadgeBorder = Color(0xFFB9A6EA);

  // Activity "state changed" icon background
  static const neutralTint = Color(0xFFE2E8F0);

  // Map placeholder background (before tiles load)
  static const mapBackground = Color(0xFFF2EFE9);
}
