import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/status_colors.dart';
import '../../core/time_format.dart';
import '../../features/activity/data/activity_event.dart';
import 'time_ago_text.dart';

/// ActivityRow(event): 64 px min height; icon in a tinted circle; absolute + relative time.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.event,
    this.showTopBorder = true,
  });

  final ActivityEvent event;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final status = context.statusColors;
    final (title, icon, color, tint) = switch (event.type) {
      ActivityEventType.cameOnline => (
        'Came online',
        Icons.wifi,
        status.moving.foreground,
        status.moving.tint,
      ),
      ActivityEventType.wentOffline => (
        'Went offline',
        Icons.wifi_off,
        status.offline.foreground,
        status.offline.tint,
      ),
      ActivityEventType.stateChanged => (
        'State changed',
        Icons.swap_horiz,
        AppPalette.primary,
        AppPalette.neutralTint,
      ),
      ActivityEventType.lowBattery => (
        'Low battery',
        Icons.battery_alert,
        status.idle.foreground,
        status.idle.tint,
      ),
      ActivityEventType.faultRaised => (
        'Fault raised',
        Icons.warning_amber_rounded,
        status.fault.foreground,
        status.fault.tint,
      ),
      ActivityEventType.unknown => (
        'Event',
        Icons.info_outline,
        AppPalette.onSurfaceVariant,
        status.offline.tint,
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: showTopBorder
            ? const Border(top: BorderSide(color: AppPalette.divider))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.labelLarge),
                if (event.details.isNotEmpty)
                  Text(
                    event.details,
                    style: AppText.bodyMedium.copyWith(
                      color: AppPalette.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                clockTime(event.occurredAt),
                style: AppText.tabular(
                  AppText.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TimeAgoText(
                event.occurredAt,
                style: AppText.tabular(
                  AppText.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppPalette.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
