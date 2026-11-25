import 'package:fleet_monitor/core/auth/auth_notifier.dart';
import 'package:fleet_monitor/core/clock.dart';
import 'package:fleet_monitor/core/realtime/ticker.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:fleet_monitor/features/vehicles/state/vehicle_list_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';

void main() {
  test(
    'the ticker marks an online vehicle stale at 31 s; dependents update only when that changes',
    () async {
      final seen = DateTime.utc(2026, 11, 26, 10);
      var now = seen;
      final repo = FakeVehiclesRepository()
        ..listAnswers.add(
          () => [
            Vehicle.fromJson({
              ...vehicleJson(id: 'a'),
              'lastSeenAt': seen.toIso8601String(),
            }),
          ],
        );
      final container = ProviderContainer.test(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          vehiclesRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('u-1'),
        ],
      );
      await container.read(vehicleListProvider.future);
      var notifications = 0;
      container.listen(staleVehicleIdsProvider, (_, _) => notifications++);
      final ticker = container.read(tickerProvider.notifier);

      for (var s = 1; s <= 30; s++) {
        now = seen.add(Duration(seconds: s));
        ticker.tick();
      }
      expect(
        container.read(staleVehicleIdsProvider).ids,
        isEmpty,
        reason: 'exactly 30 s is not stale yet',
      );
      expect(
        notifications,
        0,
        reason: '30 ticks without a change must not rebuild the list',
      );

      now = seen.add(const Duration(seconds: 31));
      ticker.tick();

      expect(container.read(staleVehicleIdsProvider).ids, {'a'});
      expect(notifications, 1);
    },
  );
}
