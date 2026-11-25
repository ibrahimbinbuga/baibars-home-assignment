import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/display_status.dart';

/// Filters are applied on the device, over the full list the server returned for this user.
/// That is only a view: the server already limited the list to the user's fleets.
class VehicleFilter {
  const VehicleFilter({this.status, this.fleetId});

  final DisplayStatus? status;
  final String? fleetId;

  bool get isActive => status != null || fleetId != null;
}

class VehicleFilterNotifier extends Notifier<VehicleFilter> {
  @override
  VehicleFilter build() => const VehicleFilter();

  void setStatus(DisplayStatus? status) =>
      state = VehicleFilter(status: status, fleetId: state.fleetId);

  /// Summary counts and chips toggle: tapping the selected status again clears it.
  void toggleStatus(DisplayStatus status) =>
      setStatus(state.status == status ? null : status);

  void setFleet(String? fleetId) =>
      state = VehicleFilter(status: state.status, fleetId: fleetId);

  void clear() => state = const VehicleFilter();
}

final vehicleFilterProvider =
    NotifierProvider<VehicleFilterNotifier, VehicleFilter>(
      VehicleFilterNotifier.new,
    );
