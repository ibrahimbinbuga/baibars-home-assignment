import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';

enum MetricVariant { normal, warning, empty }

/// MetricTile(label, value, unit, icon, variant). Warning is used for battery < 20 %; empty shows "—".
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.icon,
    this.value,
    this.unit,
    this.variant = MetricVariant.normal,
    this.progress,
    this.leading,
    this.compactValue = false,
  });

  final String label;
  final IconData icon;
  final String? value;
  final String? unit;
  final MetricVariant variant;

  /// 0..1: draws a bar under the value (battery).
  final double? progress;

  /// Shown before the value (heading compass).
  final Widget? leading;

  /// Smaller value text for multi-line values (coordinates).
  final bool compactValue;

  @override
  Widget build(BuildContext context) {
    final warning = variant == MetricVariant.warning;
    final empty = variant == MetricVariant.empty || value == null;
    final valueColor = warning ? AppPalette.error : AppPalette.onSurface;
    final valueStyle = compactValue
        ? AppText.tabular(AppText.titleSmall.copyWith(fontSize: 17))
        : AppText.metricValue.copyWith(color: valueColor);

    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: empty
            ? AppPalette.muted
            : (warning ? AppPalette.errorContainer : AppPalette.surface),
        border: Border.all(
          color: warning ? AppPalette.errorBorder : AppPalette.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!empty) ...[
                Icon(
                  icon,
                  size: 18,
                  color: warning
                      ? AppPalette.onErrorContainer
                      : AppPalette.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.labelMedium.copyWith(
                    color: warning
                        ? AppPalette.onErrorContainer
                        : AppPalette.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (empty)
            Text(
              '—',
              style: AppText.metricValue.copyWith(
                color: AppPalette.placeholder,
              ),
            )
          else
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: value,
                      style: valueStyle,
                      children: [
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: AppText.labelLarge.copyWith(
                              color: warning
                                  ? AppPalette.error
                                  : AppPalette.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (!empty && progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 8,
                color: warning ? AppPalette.error : AppPalette.onSurface,
                backgroundColor: warning
                    ? AppPalette.errorTrack
                    : AppPalette.divider,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small compass for the heading tile: a ring with an arrow rotated to the heading.
class HeadingCompass extends StatelessWidget {
  const HeadingCompass({
    super.key,
    required this.headingDeg,
    required this.semanticLabel,
  });

  final double headingDeg;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.hint, width: 1.5),
      ),
      child: Transform.rotate(
        angle: headingDeg * 3.141592653589793 / 180,
        child: const Icon(
          Icons.navigation,
          size: 20,
          color: AppPalette.primary,
        ),
      ),
    ),
  );
}
