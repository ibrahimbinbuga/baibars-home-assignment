import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/status_colors.dart';
import '../../features/vehicles/domain/display_status.dart';
import 'status_visuals.dart';

/// Filter chip: 48 px tall. Selected = filled ink + check. [dropdown] adds a chevron (fleet chip).
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dropdown = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppPalette.onPrimary : AppPalette.textStrong;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppPalette.primary : AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
          side: BorderSide(
            color: selected ? AppPalette.primary : AppPalette.outline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          child: Container(
            height: AppSpacing.tap,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected && !dropdown) ...[
                  Icon(Icons.check, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppText.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (dropdown) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.expand_more, size: 18, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Summary count (52 px): icon + count + label. Toggles the same status filter as the chips.
class SummaryCountButton extends StatelessWidget {
  const SummaryCountButton({
    super.key,
    required this.status,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final DisplayStatus status;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count ${status.label}, filter',
    selected: selected,
    button: true,
    excludeSemantics: true,
    child: Material(
      color: AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        side: BorderSide(
          color: selected ? AppPalette.primary : AppPalette.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // Scales down a little on narrow phones instead of cutting the label ("Charging").
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    status.icon,
                    size: 20,
                    color: context.statusColors.of(status).foreground,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$count',
                    style: AppText.tabular(
                      AppText.titleMedium.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    status.label,
                    style: AppText.labelMedium.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
