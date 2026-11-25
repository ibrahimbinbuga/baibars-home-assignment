import 'package:fleet_monitor/features/vehicles/data/fleet.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/domain/display_status.dart';
import 'package:fleet_monitor/features/vehicles/state/vehicle_filter.dart';
import 'package:fleet_monitor/features/vehicles/state/vehicle_list_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 11, 26, 10);
  const tarsus = Fleet(id: 'f-t', name: 'Tarsus Field Ops', region: 'Tarsus');
  const adana = Fleet(id: 'f-a', name: 'Adana Field Ops', region: 'Adana');

  Vehicle v(String id, String fleetId, String status) => Vehicle.fromJson({
        ...vehicleJson(id: id, status: status),
        'fleetId': fleetId,
        'name': id,
        'lastSeenAt': now.toIso8601String(),
      });

  final all = [v('T1', 'f-t', 'Moving'), v('T2', 'f-t', 'Idle'), v('A1', 'f-a', 'Moving'), v('A2', 'f-a', 'Charging')];

  test('counts follow the fleet filter, not the status filter', () {
    final view = buildVehicleListView(
      all: all,
      fleets: [tarsus, adana],
      filter: const VehicleFilter(fleetId: 'f-a', status: DisplayStatus.charging),
      now: now,
    );

    expect(view.shown.map((x) => x.id), ['A2']);
    expect(view.counts[DisplayStatus.moving], 1); // A1 still counted though the status filter is Charging
    expect(view.counts[DisplayStatus.charging], 1);
    expect(view.counts[DisplayStatus.idle], 0); // T2 is in another fleet
    expect(view.countLine, '1 of 4 vehicles · Adana Field Ops');
  });

  test('fleet filter only offered with more than one fleet; count line names the single fleet', () {
    final view = buildVehicleListView(all: all.take(2).toList(), fleets: [tarsus], filter: const VehicleFilter(), now: now);

    expect(view.showFleetFilter, isFalse);
    expect(view.countLine, '2 of 2 vehicles · Tarsus Field Ops');
  });

  test('empty-state message names the status and fleet', () {
    final view = buildVehicleListView(
      all: all,
      fleets: [tarsus, adana],
      filter: const VehicleFilter(fleetId: 'f-a', status: DisplayStatus.fault),
      now: now,
    );

    expect(view.shown, isEmpty);
    expect(view.emptyMessage((s) => s.name), 'No fault vehicles in Adana Field Ops right now.');
  });
}
