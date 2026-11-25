import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/status_colors.dart';
import '../../features/vehicles/domain/display_status.dart';
import 'status_visuals.dart';

enum BadgeSize { small, large }

/// StatusBadge(status, size). Small (30 px) in cards and lists, large (40 px) in the detail header.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.size = BadgeSize.small,
  });

  final DisplayStatus status;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors.of(status);
    final large = size == BadgeSize.large;
    return Container(
      height: large ? 40 : 30,
      padding: EdgeInsets.only(left: large ? 12 : 8, right: large ? 14 : 10),
      decoration: BoxDecoration(
        color: colors.tint,
        borderRadius: BorderRadius.circular(
          large ? AppRadius.chip : AppRadius.badge,
        ),
        border: Border.all(
          color: status == DisplayStatus.stale
              ? AppPalette.staleBadgeBorder
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: large ? 22 : 18, color: colors.foreground),
          SizedBox(width: large ? 8 : 6),
          Text(
            status.label,
            style:
                (large
                        ? AppText.titleSmall.copyWith(fontSize: 17)
                        : AppText.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ))
                    .copyWith(color: colors.foreground, height: 1),
          ),
        ],
      ),
    );
  }
}
