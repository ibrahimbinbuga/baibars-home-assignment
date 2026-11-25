import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/clock.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/time_format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/dashed_border.dart';
import '../../../shared/widgets/map_marker.dart';
import '../../../shared/widgets/metric_tile.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../activity/ui/activity_section.dart';
import '../../activity/ui/history_section.dart';
import '../../home/home_state.dart';
import '../data/vehicle.dart';
import '../domain/display_status.dart';
import '../state/vehicle_detail_provider.dart';
import 'vehicle_map_screen.dart';

enum _DetailTab { activity, history }

/// Vehicle detail (Detail.dc.html): header, live metrics, small map, Activity / History tabs.
class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() =>
      _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  var _tab = _DetailTab.activity;

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(liveVehicleProvider(widget.vehicleId));
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: FleetAppBar(
        title: 'Vehicle',
        showBack: true,
        titleStyle: AppText.titleLarge.copyWith(fontSize: 20),
      ),
      body: switch (vehicle) {
        AsyncData(:final value) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(vehicle: value, now: now),
            ),
            SliverToBoxAdapter(child: _LiveMetrics(vehicle: value)),
            SliverToBoxAdapter(
              child: _Tabs(
                selected: _tab,
                onSelect: (t) => setState(() => _tab = t),
              ),
            ),
            if (_tab == _DetailTab.activity)
              ActivitySection(vehicleId: value.id, now: now)
            else
              HistorySection(vehicleId: value.id),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
        AsyncError(:final error) => CenteredMessage(
          icon: Icons.warning_amber_rounded,
          iconColor: AppPalette.error,
          iconBackground: AppPalette.errorContainer,
          title: error is ApiException && error.isNotFound
              ? 'Vehicle not found'
              : 'Couldn’t load vehicle',
          message: error is ApiException && error.isNotFound
              ? 'It may have been removed, or it is not in your fleets.'
              : (error is ApiException ? error.title : 'Something went wrong.'),
          action: PrimaryAppButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: () =>
                ref.invalidate(vehicleDetailProvider(widget.vehicleId)),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vehicle, required this.now});

  final Vehicle vehicle;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final status = displayStatusOf(vehicle, now);
    final seen = vehicle.lastSeenAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(bottom: BorderSide(color: AppPalette.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  vehicle.name,
                  style: AppText.headlineMedium.copyWith(height: 34 / 28),
                ),
              ),
              Text(
                vehicle.serialNumber,
                style: AppText.tabular(
                  AppText.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppPalette.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${vehicle.fleetName} · ${vehicle.model}',
            style: AppText.labelLarge.copyWith(
              fontWeight: FontWeight.w400,
              color: AppPalette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(status: status, size: BadgeSize.large),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: AppPalette.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    seen == null
                        ? 'No data yet'
                        : 'last update ${timeAgo(seen, now)}',
                    style: AppText.tabular(
                      AppText.bodyMedium.copyWith(
                        fontWeight: seen == null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: AppPalette.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveMetrics extends ConsumerWidget {
  const _LiveMetrics({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasData = vehicle.lastTelemetryAt != null;
    final low = isLowBattery(vehicle);
    final heading = vehicle.headingDeg;

    // Two tiles per row, stretched to the taller one so the grid lines up.
    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: b),
        ],
      ),
    );
    Widget grid(List<Widget> tiles) => Column(
      children: [
        row(tiles[0], tiles[1]),
        const SizedBox(height: AppSpacing.xs),
        row(tiles[2], tiles[3]),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Live metrics', style: AppText.titleSmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!hasData) ...[
            grid(const [
              MetricTile(
                label: 'Speed',
                icon: Icons.speed,
                variant: MetricVariant.empty,
              ),
              MetricTile(
                label: 'Heading',
                icon: Icons.explore_outlined,
                variant: MetricVariant.empty,
              ),
              MetricTile(
                label: 'Battery',
                icon: Icons.battery_std,
                variant: MetricVariant.empty,
              ),
              MetricTile(
                label: 'Coordinates',
                icon: Icons.place_outlined,
                variant: MetricVariant.empty,
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            const _NoPositionYet(),
          ] else ...[
            grid([
              MetricTile(
                label: 'Speed',
                icon: Icons.speed,
                value: vehicle.speedKmh?.toStringAsFixed(1),
                unit: 'km/h',
              ),
              MetricTile(
                label: 'Heading',
                icon: Icons.explore_outlined,
                value: heading == null ? null : '${heading.round()}°',
                unit: heading == null ? null : cardinal(heading),
                leading: heading == null
                    ? null
                    : HeadingCompass(
                        headingDeg: heading,
                        semanticLabel:
                            'Heading ${heading.round()} degrees ${cardinal(heading)}',
                      ),
              ),
              MetricTile(
                label: low ? 'Low battery' : 'Battery',
                icon: low ? Icons.battery_alert : Icons.battery_std,
                value: vehicle.batteryPct?.round().toString(),
                unit: '%',
                variant: low ? MetricVariant.warning : MetricVariant.normal,
                progress: vehicle.batteryPct == null
                    ? null
                    : vehicle.batteryPct! / 100,
              ),
              MetricTile(
                label: 'Coordinates',
                icon: Icons.place_outlined,
                value: vehicle.hasLocation
                    ? '${latitudeText(vehicle.latitude!)}\n${longitudeText(vehicle.longitude!)}'
                    : null,
                compactValue: true,
              ),
            ]),
            if (vehicle.hasLocation) ...[
              const SizedBox(height: AppSpacing.sm),
              _MiniMap(
                vehicle: vehicle,
                onOpenInMap: () {
                  // Back to the shell, then show this vehicle on the app's own Map tab.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  showVehicleOnMap(ref, vehicle.id);
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniMap extends ConsumerWidget {
  const _MiniMap({required this.vehicle, required this.onOpenInMap});

  final Vehicle vehicle;
  final VoidCallback onOpenInMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = LatLng(vehicle.latitude!, vehicle.longitude!);
    final status = displayStatusOf(vehicle, ref.watch(clockProvider)());
    return Container(
      height: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.mutedBorder),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Stack(
        children: [
          FlutterMap(
            // Rebuilt with a new key when the vehicle moves, so the small map follows it.
            key: ValueKey('${position.latitude},${position.longitude}'),
            options: MapOptions(
              initialCenter: position,
              initialZoom: 14,
              backgroundColor: AppPalette.mapBackground,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: osmTileUrl,
                userAgentPackageName: tileUserAgentPackage,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: position,
                    width: 40,
                    height: 40,
                    child: MapMarker(
                      status: status,
                      lastReportedStatus: lastReportedStatus(vehicle),
                      headingDeg: vehicle.headingDeg,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: Material(
              color: AppPalette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.chip),
                side: const BorderSide(color: AppPalette.mutedBorder),
              ),
              child: InkWell(
                key: const Key('openInMap'),
                onTap: onOpenInMap,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open in map',
                        style: AppText.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppPalette.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xE6FFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                style: AppText.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppPalette.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPositionYet extends StatelessWidget {
  const _NoPositionYet();

  @override
  Widget build(BuildContext context) => DashedBorder(
    color: AppPalette.hint,
    radius: AppRadius.card,
    child: Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppPalette.muted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_off_outlined,
            size: 28,
            color: AppPalette.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('No data yet', style: AppText.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'This vehicle has not reported since it was added. Metrics and position appear after its first update.',
            textAlign: TextAlign.center,
            style: AppText.bodyMedium.copyWith(
              color: AppPalette.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final _DetailTab selected;
  final ValueChanged<_DetailTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget tab(_DetailTab value, String label) {
      final on = value == selected;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          child: InkWell(
            onTap: () => onSelect(value),
            child: Container(
              height: AppSpacing.tap,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: on ? AppPalette.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                label,
                style: AppText.labelLarge.copyWith(
                  color: on
                      ? AppPalette.onSurface
                      : AppPalette.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppPalette.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          tab(_DetailTab.activity, 'Activity'),
          tab(_DetailTab.history, 'History · last 1 h'),
        ],
      ),
    );
  }
}
