import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle.dart';
import '../data/vehicles_repository.dart';

/// One vehicle by id, from the API (404 if not visible to this user). Live updates are wired in Phase 6.
final vehicleDetailProvider = FutureProvider.autoDispose.family<Vehicle, String>(
  (ref, vehicleId) => ref.watch(vehiclesRepositoryProvider).get(vehicleId),
);
