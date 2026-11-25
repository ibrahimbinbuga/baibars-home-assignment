import '../data/vehicle.dart';

/// What the app shows for a vehicle: the server's status, plus "stale" which only the client can know.
enum DisplayStatus { moving, idle, charging, fault, offline, stale }

/// The order of the summary strip and filter chips (design: Main.dc.html).
const summaryOrder = [
  DisplayStatus.moving,
  DisplayStatus.idle,
  DisplayStatus.charging,
  DisplayStatus.fault,
  DisplayStatus.offline,
  DisplayStatus.stale,
];

/// Same as the server's offline threshold: online, but nothing received for longer than this → stale.
const staleAfter = Duration(seconds: 30);

/// The server's status is authoritative. "Stale" only covers the gap before the server's Offline message arrives:
/// the server still says online, but we haven't heard from the vehicle for more than [staleAfter].
DisplayStatus displayStatusOf(Vehicle vehicle, DateTime now) {
  final lastSeen = vehicle.lastSeenAt;
  final isOnline = vehicle.connectivity == Connectivity.online;
  if (isOnline && lastSeen != null && now.difference(lastSeen) > staleAfter) {
    return DisplayStatus.stale;
  }

  return switch (vehicle.status) {
    VehicleStatus.moving => DisplayStatus.moving,
    VehicleStatus.idle => DisplayStatus.idle,
    VehicleStatus.charging => DisplayStatus.charging,
    VehicleStatus.fault => DisplayStatus.fault,
    // A status this app version doesn't know is shown as offline: muted, never as a healthy state.
    VehicleStatus.offline || VehicleStatus.unknown => DisplayStatus.offline,
  };
}

/// "Sorted by status": what needs attention first.
int _rank(DisplayStatus status) => switch (status) {
  DisplayStatus.fault => 0,
  DisplayStatus.moving => 1,
  DisplayStatus.idle => 2,
  DisplayStatus.charging => 3,
  DisplayStatus.stale => 4,
  DisplayStatus.offline => 5,
};

/// Fault, Moving, Idle, Charging, Stale, Offline (vehicles that have reported before those that never did), then name.
int compareForList(Vehicle a, Vehicle b, DateTime now) {
  final byStatus = _rank(
    displayStatusOf(a, now),
  ).compareTo(_rank(displayStatusOf(b, now)));
  if (byStatus != 0) return byStatus;
  final byReported = (a.lastTelemetryAt == null ? 1 : 0).compareTo(
    b.lastTelemetryAt == null ? 1 : 0,
  );
  if (byReported != 0) return byReported;
  return a.name.compareTo(b.name);
}

/// Battery below this is shown as a warning (same threshold as the server's LowBattery event).
const lowBatteryPct = 20.0;

bool isLowBattery(Vehicle v) =>
    v.batteryPct != null && v.batteryPct! < lowBatteryPct;
