import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/ticker.dart';
import '../data/fleet.dart';
import '../data/fleets_repository.dart';
import '../data/vehicle.dart';
import '../domain/display_status.dart';
import 'vehicle_filter.dart';
import 'vehicle_list_notifier.dart';

/// Everything the list screen shows, computed from the full list + filter + clock. No logic in the widgets.
class VehicleListView {
  const VehicleListView({
    required this.shown,
    required this.counts,
    required this.total,
    required this.fleets,
    required this.filter,
    required this.now,
  });

  /// Filtered and sorted by status.
  final List<Vehicle> shown;

  /// Per display status, within the selected fleet (the status filter doesn't change the counts).
  final Map<DisplayStatus, int> counts;

  /// All vehicles the user can see.
  final int total;
  final List<Fleet> fleets;
  final VehicleFilter filter;
  final DateTime now;

  /// The fleet filter is only offered when there is more than one fleet to choose from.
  bool get showFleetFilter => fleets.length > 1;

  Fleet? get selectedFleet =>
      fleets.where((f) => f.id == filter.fleetId).firstOrNull;

  /// "11 of 11 vehicles · 2 fleets" / "4 of 4 vehicles · Tarsus Field Ops".
  String get countLine {
    final scope = switch ((selectedFleet, fleets.length)) {
      (final Fleet fleet?, _) => fleet.name,
      (null, 1) => fleets.single.name,
      (null, final n) => '$n fleets',
    };
    return '${shown.length} of $total vehicles · $scope';
  }

  /// Text for the empty state, e.g. "No Charging vehicles in Adana Field Ops right now."
  String emptyMessage(String Function(DisplayStatus) label) {
    final status = filter.status == null ? '' : '${label(filter.status!)} ';
    final fleet = selectedFleet == null ? '' : ' in ${selectedFleet!.name}';
    return 'No ${status}vehicles$fleet right now.';
  }
}

VehicleListView buildVehicleListView({
  required List<Vehicle> all,
  required List<Fleet> fleets,
  required VehicleFilter filter,
  required DateTime now,
}) {
  final inFleet = filter.fleetId == null
      ? all
      : all.where((v) => v.fleetId == filter.fleetId).toList();
  final counts = {for (final s in DisplayStatus.values) s: 0};
  for (final v in inFleet) {
    counts.update(displayStatusOf(v, now), (n) => n + 1);
  }
  final shown =
      (filter.status == null
            ? [...inFleet]
            : inFleet
                  .where((v) => displayStatusOf(v, now) == filter.status)
                  .toList())
        ..sort((a, b) => compareForList(a, b, now));
  return VehicleListView(
    shown: shown,
    counts: counts,
    total: all.length,
    fleets: fleets,
    filter: filter,
    now: now,
  );
}

/// The list screen's data. Loading/error come from the vehicle list; fleets only decide whether the fleet chip shows.
final vehicleListViewProvider = Provider<AsyncValue<VehicleListView>>((ref) {
  final filter = ref.watch(vehicleFilterProvider);
  final fleets = ref.watch(fleetsProvider).value ?? const <Fleet>[];
  // Rebuild when a vehicle becomes (or stops being) stale, not on every tick; "now" is read, not watched.
  ref.watch(staleVehicleIdsProvider);
  final now = ref.read(tickerProvider);
  return ref
      .watch(vehicleListProvider)
      .whenData(
        (state) => buildVehicleListView(
          all: state.vehicles,
          fleets: fleets,
          filter: filter,
          now: now,
        ),
      );
});
