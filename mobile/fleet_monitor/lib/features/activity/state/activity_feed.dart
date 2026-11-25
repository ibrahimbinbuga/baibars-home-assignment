import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
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
}

/// Activity for one vehicle, paged with the server's opaque cursor ("Load more").
class ActivityFeedNotifier extends AsyncNotifier<ActivityFeedState> {
  ActivityFeedNotifier(this.vehicleId);

  final String vehicleId;
  static const pageSize = 20;

  @override
  Future<ActivityFeedState> build() async {
    final page = await ref
        .read(vehiclesRepositoryProvider)
        .activity(vehicleId, limit: pageSize);
    return ActivityFeedState(items: page.items, nextBefore: page.nextBefore);
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
      state = AsyncData(
        ActivityFeedState(
          items: [...current.items, ...page.items],
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
