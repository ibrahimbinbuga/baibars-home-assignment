import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/clock.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/time_format.dart';
import '../../../shared/widgets/map_marker.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/status_visuals.dart';
import '../../home/home_state.dart';
import '../data/vehicle.dart';
import '../domain/display_status.dart';
import '../state/vehicle_list_notifier.dart';
import 'vehicle_detail_screen.dart';

/// OSM's public tile servers: fine for a demo, not for production use (see DECISIONS.md).
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Required by the OSM tile usage policy: identify the app.
const tileUserAgentPackage = 'io.github.ibrahimbinbuga.fleet_monitor';

/// Used before any vehicle has a position: the Çukurova plain between Tarsus and Adana.
const _fallbackCenter = LatLng(36.95, 35.1);

/// The status the vehicle last reported, for the shape of a stale marker.
DisplayStatus? lastReportedStatus(Vehicle v) => switch (v.status) {
  VehicleStatus.moving => DisplayStatus.moving,
  VehicleStatus.idle => DisplayStatus.idle,
  VehicleStatus.charging => DisplayStatus.charging,
  VehicleStatus.fault => DisplayStatus.fault,
  _ => null,
};

/// Vehicles · Map tab (Map.dc.html): status markers, legend, zoom/fit controls, preview panel.
class VehicleMapScreen extends ConsumerStatefulWidget {
  const VehicleMapScreen({super.key});

  @override
  ConsumerState<VehicleMapScreen> createState() => _VehicleMapScreenState();
}

class _VehicleMapScreenState extends ConsumerState<VehicleMapScreen> {
  final _map = MapController();
  bool _mapReady = false;
  bool _fittedOnce = false;

  /// True while a selection comes from tapping a marker here: that must not move the camera.
  /// Only a selection from outside ("Open in map" on the detail screen) centres the map on the vehicle.
  bool _selectingOnMap = false;

  void _selectOnMap(String? vehicleId) {
    _selectingOnMap = true;
    ref.read(mapSelectionProvider.notifier).select(vehicleId);
    _selectingOnMap = false;
  }

  List<Vehicle> get _located =>
      (ref.read(vehicleListProvider).value?.vehicles ?? const <Vehicle>[])
          .where((v) => v.hasLocation)
          .toList();

  void _fitAll() {
    final located = _located;
    if (!_mapReady || located.isEmpty) return;
    if (located.length == 1) {
      _map.move(
        LatLng(located.single.latitude!, located.single.longitude!),
        14,
      );
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          for (final v in located) LatLng(v.latitude!, v.longitude!),
        ],
        padding: const EdgeInsets.fromLTRB(48, 80, 72, 140),
      ),
    );
  }

  void _focusSelected() {
    final id = ref.read(mapSelectionProvider);
    final vehicle = id == null
        ? null
        : ref.read(vehicleListProvider).value?.byId(id);
    if (_mapReady && vehicle != null && vehicle.hasLocation) {
      _map.move(LatLng(vehicle.latitude!, vehicle.longitude!), 15);
    }
  }

  void _zoom(double delta) {
    if (!_mapReady) return;
    _map.move(_map.camera.center, (_map.camera.zoom + delta).clamp(3, 18));
  }

  @override
  Widget build(BuildContext context) {
    // "Open in map" from the detail screen selects a vehicle: centre on it.
    ref.listen(mapSelectionProvider, (_, id) {
      if (id != null && !_selectingOnMap) _focusSelected();
    });
    // Fit all vehicles once, when positions first become available.
    ref.listen(vehicleListProvider, (_, next) {
      if (!_fittedOnce && next.value != null && _located.isNotEmpty) {
        _fittedOnce = true;
        _fitAll();
      }
    });

    final vehicles =
        ref.watch(vehicleListProvider).value?.vehicles ?? const <Vehicle>[];
    final selectedId = ref.watch(mapSelectionProvider);
    final now = ref.watch(clockProvider)();
    final located = vehicles.where((v) => v.hasLocation).toList();
    final withoutLocation = vehicles.length - located.length;
    final selected = selectedId == null
        ? null
        : vehicles.where((v) => v.id == selectedId).firstOrNull;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _fallbackCenter,
            initialZoom: 10,
            backgroundColor: AppPalette.mapBackground,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => _selectOnMap(null),
            onMapReady: () {
              _mapReady = true;
              if (selectedId != null) {
                _focusSelected();
              } else if (located.isNotEmpty) {
                _fittedOnce = true;
                _fitAll();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: osmTileUrl,
              userAgentPackageName: tileUserAgentPackage,
            ),
            MarkerLayer(
              markers: [
                for (final v in located)
                  Marker(
                    key: ValueKey(v.id),
                    point: LatLng(v.latitude!, v.longitude!),
                    width: 72,
                    height: 80,
                    // Marker centre on the position; the name tag hangs below.
                    alignment: const Alignment(0, 0.35),
                    child: _VehicleMarker(
                      vehicle: v,
                      now: now,
                      selected: v.id == selectedId,
                      onTap: () => _selectOnMap(v.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (withoutLocation > 0)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            right: 72,
            child: _MapNotice(
              text: withoutLocation == 1
                  ? '1 vehicle has no location yet'
                  : '$withoutLocation vehicles have no location yet',
            ),
          ),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: _MapControls(
            onZoomIn: () => _zoom(1),
            onZoomOut: () => _zoom(-1),
            onFit: _fitAll,
          ),
        ),
        if (selected != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VehiclePreviewPanel(vehicle: selected, now: now),
          )
        else ...[
          const Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: 32,
            child: _Legend(),
          ),
          const Positioned(right: 0, bottom: 0, child: _Attribution()),
        ],
      ],
    );
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({
    required this.vehicle,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = displayStatusOf(vehicle, now);
    return Semantics(
      button: true,
      label: '${vehicle.name}, ${status.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: MapMarker.selectedSize,
              child: Center(
                child: MapMarker(
                  status: status,
                  lastReportedStatus: lastReportedStatus(vehicle),
                  headingDeg: vehicle.headingDeg,
                  selected: selected,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                border: Border.all(color: AppPalette.hint),
                borderRadius: BorderRadius.circular(AppRadius.mapTag),
              ),
              child: Text(vehicle.name, style: AppText.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  const _MapNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppPalette.surface,
      border: Border.all(color: AppPalette.mutedBorder),
      borderRadius: BorderRadius.circular(AppRadius.input),
      boxShadow: AppShadows.level1,
    ),
    child: Row(
      children: [
        const Icon(
          Icons.info_outline,
          size: 18,
          color: AppPalette.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppText.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppPalette.textStrong,
            ),
          ),
        ),
      ],
    ),
  );
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String tooltip,
      VoidCallback onTap, {
      bool top = false,
      bool bottom = false,
    }) => Material(
      color: AppPalette.surface,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox.square(
            dimension: AppSpacing.tap,
            child: Icon(icon, size: 22, color: AppPalette.onSurface),
          ),
        ),
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: AppPalette.mutedBorder),
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        children: [
          button(Icons.add, 'Zoom in', onZoomIn),
          const Divider(height: 1, color: AppPalette.mutedBorder),
          button(Icons.remove, 'Zoom out', onZoomOut),
          const Divider(height: 1, color: AppPalette.mutedBorder),
          button(Icons.fit_screen_outlined, 'Fit all vehicles', onFit),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      color: AppPalette.surface,
      border: Border.all(color: AppPalette.mutedBorder),
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: AppShadows.level1,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final status in [
          DisplayStatus.moving,
          DisplayStatus.idle,
          DisplayStatus.charging,
          DisplayStatus.fault,
          DisplayStatus.offline,
          DisplayStatus.stale,
        ])
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: 0.67,
                child: MapMarker(
                  status: status,
                  lastReportedStatus: DisplayStatus.moving,
                ),
              ),
              Text(
                status.label,
                style: AppText.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textStrong,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xE6FFFFFF),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
    child: Text(
      '© OpenStreetMap contributors',
      style: AppText.labelSmall.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppPalette.textMuted,
      ),
    ),
  );
}

/// Bottom preview after tapping a marker (Map.dc.html 3.2).
class VehiclePreviewPanel extends ConsumerWidget {
  const VehiclePreviewPanel({
    super.key,
    required this.vehicle,
    required this.now,
  });

  final Vehicle vehicle;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = displayStatusOf(vehicle, now);
    final heading = vehicle.headingDeg;
    String value(Object? v, String Function() text) => v == null ? '—' : text();

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
        boxShadow: AppShadows.level3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.hint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.name, style: AppText.titleLarge),
                    Text(
                      '${vehicle.fleetName} · ${vehicle.model}',
                      style: AppText.bodyMedium.copyWith(
                        color: AppPalette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PreviewValue(
                'Battery',
                value(
                  vehicle.batteryPct,
                  () => '${vehicle.batteryPct!.round()}%',
                ),
              ),
              _PreviewValue(
                'Speed',
                value(
                  vehicle.speedKmh,
                  () => '${vehicle.speedKmh!.toStringAsFixed(1)} km/h',
                ),
              ),
              _PreviewValue(
                'Heading',
                value(
                  heading,
                  () => '${heading!.round()}° ${cardinal(heading)}',
                ),
              ),
              _PreviewValue(
                'Updated',
                value(
                  vehicle.lastSeenAt,
                  () => timeAgo(vehicle.lastSeenAt!, now),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                textStyle: AppText.titleSmall,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View details'),
                  SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewValue extends StatelessWidget {
  const _PreviewValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppPalette.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.tabular(AppText.titleSmall.copyWith(fontSize: 17)),
            ),
          ),
        ],
      ),
    ),
  );
}
