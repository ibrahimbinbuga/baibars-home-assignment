import '../data/vehicle.dart';

/// All vehicles the user can see. Filters are applied on top (see vehicle_filter.dart), so a live update can always be
/// applied by id, whatever the current filter.
///
/// Ordering rule, for live updates and REST snapshots alike: per vehicle, keep the copy with the greater updatedAt
/// (server time, strictly increasing per vehicle). Equal or older copies are ignored.
class VehicleListState {
  const VehicleListState(this.vehicles);

  static const empty = VehicleListState([]);

  final List<Vehicle> vehicles;

  /// Applies a live update. Ignored if it isn't strictly newer than what we have, or if the vehicle isn't in the
  /// list (the next snapshot brings new vehicles in).
  VehicleListState applyUpdate(Vehicle update) {
    final index = vehicles.indexWhere((v) => v.id == update.id);
    if (index < 0 || !update.isNewerThan(vehicles[index])) return this;
    return VehicleListState([...vehicles]..[index] = update);
  }

  /// Merges a fresh REST snapshot. The snapshot decides WHICH vehicles are in the list (access may have changed),
  /// but for each vehicle a live update newer than the snapshot wins: the snapshot may have been read before that
  /// update happened and only arrived after it.
  VehicleListState mergeSnapshot(List<Vehicle> snapshot) {
    final current = {for (final v in vehicles) v.id: v};
    return VehicleListState([
      for (final fromSnapshot in snapshot)
        if (current[fromSnapshot.id] case final existing? when existing.isNewerThan(fromSnapshot))
          existing
        else
          fromSnapshot,
    ]);
  }

  Vehicle? byId(String id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }
}
