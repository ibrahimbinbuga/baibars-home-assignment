import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/vehicle.dart';
import 'vehicle_list_notifier.dart';

/// Filters are applied on the device, over the full list the server returned for this user.
/// That is only a view: the server already limited the list to the user's fleets.
class VehicleFilter {
  const VehicleFilter({this.status, this.fleetId});

  final VehicleStatus? status;
  final String? fleetId;

  bool matches(Vehicle v) => (status == null || v.status == status) && (fleetId == null || v.fleetId == fleetId);
}

class VehicleFilterNotifier extends Notifier<VehicleFilter> {
  @override
  VehicleFilter build() => const VehicleFilter();

  void setStatus(VehicleStatus? status) => state = VehicleFilter(status: status, fleetId: state.fleetId);
  void setFleet(String? fleetId) => state = VehicleFilter(status: state.status, fleetId: fleetId);
}

final vehicleFilterProvider = NotifierProvider<VehicleFilterNotifier, VehicleFilter>(VehicleFilterNotifier.new);

/// The list as shown: full list + current filter.
final filteredVehiclesProvider = Provider<AsyncValue<List<Vehicle>>>((ref) {
  final filter = ref.watch(vehicleFilterProvider);
  return ref.watch(vehicleListProvider).whenData((state) => state.vehicles.where(filter.matches).toList());
});
