import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/state/vehicle_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 26, 10);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('applyUpdate (live VehicleUpdated)', () {
    final state = VehicleListState([vehicle(id: 'a', status: 'Idle', updatedAt: at(10)), vehicle(id: 'b', updatedAt: at(10))]);

    test('newer update is applied', () {
      final next = state.applyUpdate(vehicle(id: 'a', status: 'Moving', updatedAt: at(12)));

      expect(next.byId('a')!.status, VehicleStatus.moving);
      expect(next.byId('b'), same(state.byId('b')));
    });

    test('older update is ignored', () {
      final next = state.applyUpdate(vehicle(id: 'a', status: 'Moving', updatedAt: at(9)));

      expect(next, same(state));
    });

    test('equal updatedAt is ignored (same version)', () {
      final next = state.applyUpdate(vehicle(id: 'a', status: 'Moving', updatedAt: at(10)));

      expect(next, same(state));
    });

    test('Offline flip is applied (its updatedAt is newer even though lastTelemetryAt is unchanged)', () {
      final online = VehicleListState([vehicle(id: 'a', status: 'Moving', updatedAt: at(10))]);

      final next = online.applyUpdate(vehicle(id: 'a', status: 'Offline', updatedAt: at(40)));

      expect(next.byId('a')!.status, VehicleStatus.offline);
      expect(next.byId('a')!.lastTelemetryAt, online.byId('a')!.lastTelemetryAt);
    });

    test('update for a vehicle not in the list is ignored', () {
      final next = state.applyUpdate(vehicle(id: 'zzz', updatedAt: at(99)));

      expect(next, same(state));
    });

    test('a 1 µs difference counts (server timestamps have microsecond precision)', () {
      final next = state.applyUpdate(vehicle(id: 'a', status: 'Moving', updatedAt: at(10).add(const Duration(microseconds: 1))));

      expect(next.byId('a')!.status, VehicleStatus.moving);
    });
  });

  group('mergeSnapshot (REST re-fetch)', () {
    test('a snapshot read before a live Offline update does not undo it', () {
      // Live: vehicle went Offline at t=40. A REST response read at t=35 (still Online) arrives afterwards.
      final live = VehicleListState([vehicle(id: 'a', status: 'Offline', updatedAt: at(40))]);

      final merged = live.mergeSnapshot([vehicle(id: 'a', status: 'Moving', updatedAt: at(35))]);

      expect(merged.byId('a')!.status, VehicleStatus.offline);
    });

    test('a newer snapshot replaces the stored copy', () {
      final current = VehicleListState([vehicle(id: 'a', status: 'Offline', updatedAt: at(40))]);

      final merged = current.mergeSnapshot([vehicle(id: 'a', status: 'Moving', updatedAt: at(50))]);

      expect(merged.byId('a')!.status, VehicleStatus.moving);
    });

    test('the snapshot decides which vehicles are listed (added and removed) and their order', () {
      final current = VehicleListState([vehicle(id: 'a', updatedAt: at(10)), vehicle(id: 'gone', updatedAt: at(10))]);

      final merged = current.mergeSnapshot([vehicle(id: 'new', updatedAt: at(5)), vehicle(id: 'a', updatedAt: at(10))]);

      expect(merged.vehicles.map((v) => v.id), ['new', 'a']);
    });

    test('merging into an empty list takes the snapshot as is', () {
      final merged = VehicleListState.empty.mergeSnapshot([vehicle(id: 'a', updatedAt: at(1))]);

      expect(merged.vehicles.single.id, 'a');
    });
  });
}
