import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/realtime/realtime_controller.dart';
import '../../vehicles/data/vehicles_repository.dart';
import '../data/activity_event.dart';

class ActivityFeedState {
  const ActivityFeedState({
    required this.items,
    this.nextBefore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  /// Newest first.
  final List<ActivityEvent> items;

  /// Cursor for the next (older) page; null when everything is loaded.
  final String? nextBefore;
  final bool loadingMore;

  /// Set when "Load more" failed; the loaded items stay.
  final ApiException? loadMoreError;

  bool get hasMore => nextBefore != null;

  /// Adds a live event at its place (newest first). An event already in the list (same id) is ignored.
  ActivityFeedState withLive(ActivityEvent event) {
    if (items.any((e) => e.id == event.id)) return this;
    final merged = [...items, event]
      ..sort((a, b) {
        final byTime = b.occurredAt.compareTo(a.occurredAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return ActivityFeedState(
      items: merged,
      nextBefore: nextBefore,
      loadingMore: loadingMore,
      loadMoreError: loadMoreError,
    );
  }
}

/// Activity for one vehicle, paged with the server's opaque cursor ("Load more").
class ActivityFeedNotifier extends AsyncNotifier<ActivityFeedState> {
  ActivityFeedNotifier(this.vehicleId);

  final String vehicleId;
  static const pageSize = 20;

  @override
  Future<ActivityFeedState> build() async {
    // Live ActivityRaised events for this vehicle. Events arriving while the first page is loading are kept and
    // merged in afterwards (deduplicated by id), so nothing is lost in between.
    final pending = <ActivityEvent>[];
    final subscription = ref
        .read(liveActivityProvider)
        .stream
        .where((e) => e.vehicleId == vehicleId)
        .listen((e) {
          final current = state.value;
          if (current == null) {
            pending.add(e);
          } else {
            state = AsyncData(current.withLive(e));
          }
        });
    ref.onDispose(subscription.cancel);

    final page = await ref
        .read(vehiclesRepositoryProvider)
        .activity(vehicleId, limit: pageSize);
    var result = ActivityFeedState(
      items: page.items,
      nextBefore: page.nextBefore,
    );
    for (final e in pending) {
      result = result.withLive(e);
    }
    return result;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      ActivityFeedState(
        items: current.items,
        nextBefore: current.nextBefore,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(vehiclesRepositoryProvider)
          .activity(vehicleId, before: current.nextBefore, limit: pageSize);
      if (!ref.mounted) return;
      // Start from the latest items (live events may have arrived while loading), then append the older page.
      final latest = state.value ?? current;
      final known = latest.items.map((e) => e.id).toSet();
      state = AsyncData(
        ActivityFeedState(
          items: [
            ...latest.items,
            ...page.items.where((e) => !known.contains(e.id)),
          ],
          nextBefore: page.nextBefore,
        ),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        ActivityFeedState(
          items: current.items,
          nextBefore: current.nextBefore,
          loadMoreError: e,
        ),
      );
    }
  }
}

final activityFeedProvider = AsyncNotifierProvider.autoDispose
    .family<ActivityFeedNotifier, ActivityFeedState, String>(
      ActivityFeedNotifier.new,
    );
