import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../data/vehicle.dart';
import '../data/vehicles_repository.dart';
import 'vehicle_list_state.dart';

class VehicleListNotifier extends AsyncNotifier<VehicleListState> {
  @override
  Future<VehicleListState> build() async {
    // Rebuilt (and emptied) when the user logs out or another user logs in: no data carries over between users.
    if (ref.watch(currentUserIdProvider) == null) return VehicleListState.empty;
    return VehicleListState(await ref.read(vehiclesRepositoryProvider).list());
  }

  /// Pull-to-refresh / reconnect. Throws ApiException on failure and keeps the current list.
  Future<void> refresh() async {
    final snapshot = await ref.read(vehiclesRepositoryProvider).list();
    state = AsyncData((state.value ?? VehicleListState.empty).mergeSnapshot(snapshot));
  }

  /// A live VehicleUpdated (Phase 6). Ignored if older than what we have.
  void applyUpdate(Vehicle update) {
    final current = state.value;
    if (current != null) state = AsyncData(current.applyUpdate(update));
  }
}

final vehicleListProvider = AsyncNotifierProvider<VehicleListNotifier, VehicleListState>(VehicleListNotifier.new);
