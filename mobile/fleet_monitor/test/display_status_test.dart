import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/domain/display_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

Vehicle at({
  String id = 'v',
  String status = 'Moving',
  required DateTime lastSeen,
  String name = 'X',
  bool reported = true,
}) => Vehicle.fromJson({
  ...vehicleJson(id: id, status: status),
  'name': name,
  'lastSeenAt': lastSeen.toIso8601String(),
  if (!reported) 'lastTelemetryAt': null,
});

void main() {
  final now = DateTime.utc(2026, 11, 26, 10);

  group('stale', () {
    test('online and last seen exactly 30 s ago is not stale yet', () {
      expect(
        displayStatusOf(
          at(lastSeen: now.subtract(const Duration(seconds: 30))),
          now,
        ),
        DisplayStatus.moving,
      );
    });

    test('online and last seen 31 s ago is stale', () {
      expect(
        displayStatusOf(
          at(lastSeen: now.subtract(const Duration(seconds: 31))),
          now,
        ),
        DisplayStatus.stale,
      );
    });

    test('the server saying Offline wins over stale', () {
      final v = at(
        status: 'Offline',
        lastSeen: now.subtract(const Duration(minutes: 5)),
      );
      expect(displayStatusOf(v, now), DisplayStatus.offline);
    });

    test('an unknown status is shown as offline, never as healthy', () {
      final v = Vehicle.fromJson({
        ...vehicleJson(),
        'status': 'Teleporting',
        'lastSeenAt': now.toIso8601String(),
      });
      expect(displayStatusOf(v, now), DisplayStatus.offline);
    });
  });

  test(
    'sort: Fault, Moving, Idle, Charging, Stale, Offline (reported first), then name',
    () {
      final fresh = now.subtract(const Duration(seconds: 2));
      final old = now.subtract(const Duration(minutes: 2));
      final vehicles = [
        at(
          id: '1',
          name: 'Z-off-never',
          status: 'Offline',
          lastSeen: old,
          reported: false,
        ),
        at(id: '2', name: 'A-off-reported', status: 'Offline', lastSeen: old),
        at(id: '3', name: 'stale', status: 'Moving', lastSeen: old),
        at(id: '4', name: 'charging', status: 'Charging', lastSeen: fresh),
        at(id: '5', name: 'idle', status: 'Idle', lastSeen: fresh),
        at(id: '6', name: 'B-moving', status: 'Moving', lastSeen: fresh),
        at(id: '7', name: 'A-moving', status: 'Moving', lastSeen: fresh),
        at(id: '8', name: 'fault', status: 'Fault', lastSeen: fresh),
      ]..sort((a, b) => compareForList(a, b, now));

      expect(vehicles.map((v) => v.name), [
        'fault',
        'A-moving',
        'B-moving',
        'idle',
        'charging',
        'stale',
        'A-off-reported',
        'Z-off-never',
      ]);
    },
  );
}
