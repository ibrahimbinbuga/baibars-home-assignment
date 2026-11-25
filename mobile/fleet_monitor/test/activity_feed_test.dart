import 'package:fleet_monitor/core/api/api_exception.dart';
import 'package:fleet_monitor/features/activity/data/activity_event.dart';
import 'package:fleet_monitor/features/activity/state/activity_feed.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ActivityEvent e(int id) => ActivityEvent(
    id: id, vehicleId: 'v', type: ActivityEventType.stateChanged, occurredAt: DateTime.utc(2026), details: 'e$id');

void main() {
  late FakeVehiclesRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeVehiclesRepository();
    container = ProviderContainer.test(overrides: [vehiclesRepositoryProvider.overrideWithValue(repo)]);
  });

  test('Load more passes the cursor and appends the next page', () async {
    repo.activityPages
      ..add(ActivityPage(items: [e(3), e(2)], nextBefore: 'cursor-1'))
      ..add(ActivityPage(items: [e(1)]));
    await container.read(activityFeedProvider('v').future);

    await container.read(activityFeedProvider('v').notifier).loadMore();

    final state = container.read(activityFeedProvider('v')).value!;
    expect(state.items.map((x) => x.id), [3, 2, 1]);
    expect(state.hasMore, isFalse);
    expect(repo.activityBefores, [null, 'cursor-1']);
  });

  test('no request when there is nothing more to load', () async {
    repo.activityPages.add(ActivityPage(items: [e(1)]));
    await container.read(activityFeedProvider('v').future);

    await container.read(activityFeedProvider('v').notifier).loadMore();

    expect(repo.activityBefores, [null]);
  });

  test('a failed Load more keeps the loaded items and reports the error', () async {
    repo.activityPages.add(ActivityPage(items: [e(2)], nextBefore: 'c'));
    await container.read(activityFeedProvider('v').future);
    repo.activityError = const ApiException(kind: ApiErrorKind.network, title: 'Cannot reach the server');

    await container.read(activityFeedProvider('v').notifier).loadMore();

    final state = container.read(activityFeedProvider('v')).value!;
    expect(state.items.map((x) => x.id), [2]);
    expect(state.loadMoreError?.title, 'Cannot reach the server');
    expect(state.hasMore, isTrue);
  });
}
