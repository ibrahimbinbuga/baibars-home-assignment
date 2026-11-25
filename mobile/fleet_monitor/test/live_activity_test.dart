import 'dart:async';

import 'package:fleet_monitor/core/realtime/realtime_controller.dart';
import 'package:fleet_monitor/features/activity/data/activity_event.dart';
import 'package:fleet_monitor/features/activity/state/activity_feed.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ActivityEvent e(int id, {String vehicleId = 'v', int minute = 0}) =>
    ActivityEvent(
      id: id,
      vehicleId: vehicleId,
      type: ActivityEventType.stateChanged,
      occurredAt: DateTime.utc(2026, 11, 26, 10, minute),
      details: 'e$id',
    );

void main() {
  late FakeVehiclesRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeVehiclesRepository();
    container = ProviderContainer.test(
      overrides: [vehiclesRepositoryProvider.overrideWithValue(repo)],
    );
  });

  StreamController<ActivityEvent> live() =>
      container.read(liveActivityProvider);
  List<int> ids() => container
      .read(activityFeedProvider('v'))
      .value!
      .items
      .map((x) => x.id)
      .toList();

  test(
    'ActivityRaised is prepended to the open feed; a duplicate id is ignored',
    () async {
      repo.activityPages.add(
        ActivityPage(items: [e(2, minute: 2), e(1, minute: 1)]),
      );
      container.listen(
        activityFeedProvider('v'),
        (_, _) {},
      ); // the feed is open on screen
      await container.read(activityFeedProvider('v').future);

      live().add(e(3, minute: 3));
      live().add(
        e(3, minute: 3),
      ); // same event twice (e.g. delivered again after a reconnect)
      live().add(e(9, vehicleId: 'other', minute: 4)); // another vehicle's feed
      await pumpEventQueue();

      expect(ids(), [3, 2, 1]);
    },
  );

  test(
    'an event that arrives while the first page is loading is merged in, not lost or doubled',
    () async {
      final gate = Completer<void>();
      repo.activityGate = gate;
      repo.activityPages.add(
        ActivityPage(items: [e(2, minute: 2), e(1, minute: 1)]),
      );
      container.listen(
        activityFeedProvider('v'),
        (_, _) {},
      ); // the feed is open on screen
      final loading = container.read(activityFeedProvider('v').future);
      await pumpEventQueue();

      live().add(e(3, minute: 3)); // new while loading
      live().add(e(2, minute: 2)); // also in the page that is loading
      await pumpEventQueue();
      gate.complete();
      await loading;

      expect(ids(), [3, 2, 1]);
    },
  );
}
