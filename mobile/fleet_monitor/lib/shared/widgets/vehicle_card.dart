import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/status_colors.dart';
import '../../core/time_format.dart';
import '../../features/vehicles/data/vehicle.dart';
import '../../features/vehicles/domain/display_status.dart';
import 'dashed_border.dart';
import 'status_badge.dart';
import 'status_visuals.dart';

/// VehicleCard(vehicle). The whole card is the tap target (min 96 px). Stale and Offline are muted (grey surface);
/// Stale also gets a dashed outline; Fault gets a red outline.
class VehicleCard extends StatelessWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.now,
    this.onTap,
  });

  final Vehicle vehicle;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = displayStatusOf(vehicle, now);
    final muted =
        status == DisplayStatus.offline || status == DisplayStatus.stale;
    final borderColor = switch (status) {
      DisplayStatus.fault => AppPalette.errorBorder,
      DisplayStatus.stale =>
        Colors.transparent, // dashed outline painted on top
      _ when muted => AppPalette.mutedBorder,
      _ => AppPalette.outlineVariant,
    };
    final radius = BorderRadius.circular(AppRadius.card);

    Widget card = Material(
      color: muted ? AppPalette.muted : AppPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name,
                            style: AppText.titleMedium.copyWith(
                              color: muted ? AppPalette.textMuted : null,
                            ),
                          ),
                          Text(
                            vehicle.fleetName,
                            style: AppText.bodyMedium.copyWith(
                              color: AppPalette.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (vehicle.lastTelemetryAt == null)
                  const _NoDataRow()
                else
                  _MetricsRow(vehicle, status, now),
              ],
            ),
          ),
        ),
      ),
    );

    if (status == DisplayStatus.stale) {
      card = DashedBorder(
        color: AppPalette.staleCardBorder,
        radius: AppRadius.card,
        child: card,
      );
    }
    return Semantics(
      label: _semanticLabel(status),
      button: onTap != null,
      excludeSemantics: true,
      child: card,
    );
  }

  String _semanticLabel(DisplayStatus status) {
    final base = '${vehicle.name}, ${vehicle.fleetName}, ${status.label}';
    if (vehicle.lastTelemetryAt == null) return '$base, no data yet';
    final battery = vehicle.batteryPct == null
        ? ''
        : ', battery ${vehicle.batteryPct!.round()}%';
    return '$base$battery, ${updatedText(vehicle, status, now)}';
  }
}

/// "updated 4s ago" while live; "last seen 2m ago" when stale or offline.
String updatedText(Vehicle vehicle, DisplayStatus status, DateTime now) {
  final seen = vehicle.lastSeenAt;
  if (seen == null) return 'Never reported';
  final live = status != DisplayStatus.stale && status != DisplayStatus.offline;
  return '${live ? 'updated' : 'last seen'} ${timeAgo(seen, now)}';
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow(this.vehicle, this.status, this.now);

  final Vehicle vehicle;
  final DisplayStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final muted =
        status == DisplayStatus.offline || status == DisplayStatus.stale;
    final low = isLowBattery(vehicle) && !muted;
    final metricColor = muted
        ? AppPalette.onSurfaceVariant
        : AppPalette.onSurface;
    final value = AppText.tabular(AppText.labelLarge);
    final speed = status == DisplayStatus.offline || vehicle.speedKmh == null
        ? '— km/h'
        : '${vehicle.speedKmh!.toStringAsFixed(1)} km/h';

    return Row(
      children: [
        Icon(
          low ? Icons.battery_alert : Icons.battery_std,
          size: 18,
          color: low ? AppPalette.error : metricColor,
        ),
        const SizedBox(width: 6),
        Text(
          vehicle.batteryPct == null ? '—' : '${vehicle.batteryPct!.round()}%',
          style: value.copyWith(color: low ? AppPalette.error : metricColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(Icons.speed, size: 18, color: metricColor),
        const SizedBox(width: 6),
        Text(speed, style: value.copyWith(color: metricColor)),
        const Spacer(),
        Icon(
          Icons.schedule,
          size: 14,
          color: status == DisplayStatus.stale
              ? context.statusColors.stale.foreground
              : AppPalette.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          updatedText(vehicle, status, now),
          style: AppText.tabular(AppText.labelMedium).copyWith(
            fontWeight: FontWeight.w400,
            color: status == DisplayStatus.stale
                ? context.statusColors.stale.foreground
                : AppPalette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _NoDataRow extends StatelessWidget {
  const _NoDataRow();

  @override
  Widget build(BuildContext context) {
    final style = AppText.labelLarge.copyWith(
      color: AppPalette.onSurfaceVariant,
    );
    return Row(
      children: [
        const Icon(
          Icons.remove_circle_outline,
          size: 18,
          color: AppPalette.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text('No data yet', style: style),
        const Spacer(),
        Text(
          'Never reported',
          style: AppText.labelMedium.copyWith(
            fontWeight: FontWeight.w400,
            color: AppPalette.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
