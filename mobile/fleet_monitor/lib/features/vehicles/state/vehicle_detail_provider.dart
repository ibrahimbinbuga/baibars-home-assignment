import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle.dart';
import '../data/vehicles_repository.dart';
import 'vehicle_list_notifier.dart';

/// One vehicle by id, from the API (404 if not visible to this user).
final vehicleDetailProvider = FutureProvider.autoDispose
    .family<Vehicle, String>(
      (ref, vehicleId) => ref.watch(vehiclesRepositoryProvider).get(vehicleId),
    );

/// The vehicle as the detail screen shows it: taken from the shared list state when it is there (so list and detail
/// always show the same, and live updates reach both), otherwise fetched on its own.
final liveVehicleProvider = Provider.autoDispose
    .family<AsyncValue<Vehicle>, String>((ref, vehicleId) {
      final fromList = ref.watch(vehicleListProvider).value?.byId(vehicleId);
      if (fromList != null) return AsyncData(fromList);
      return ref.watch(vehicleDetailProvider(vehicleId));
    });
