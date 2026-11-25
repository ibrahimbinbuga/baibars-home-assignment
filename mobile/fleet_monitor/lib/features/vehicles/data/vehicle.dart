import '../../../core/json.dart';

/// What the user sees: the reported state while online, otherwise offline (decided by the server).
enum VehicleStatus { moving, idle, charging, fault, offline, unknown }

enum Connectivity { online, offline, unknown }

/// VehicleDto from the API (docs/API.md). Location and metrics are null until the first telemetry sample.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.fleetId,
    required this.fleetName,
    required this.name,
    required this.model,
    required this.serialNumber,
    required this.status,
    required this.connectivity,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.speedKmh,
    this.headingDeg,
    this.batteryPct,
    this.lastTelemetryAt,
    this.lastSeenAt,
  });

  final String id;
  final String fleetId;
  final String fleetName;
  final String name;
  final String model;
  final String serialNumber;
  final VehicleStatus status;
  final Connectivity connectivity;
  final double? latitude;
  final double? longitude;
  final double? speedKmh;
  final double? headingDeg;
  final double? batteryPct;

  /// Vehicle clock of the latest sample.
  final DateTime? lastTelemetryAt;

  /// Server clock when the last sample arrived.
  final DateTime? lastSeenAt;

  /// Server time of the last change to this vehicle. Strictly increases per vehicle: the ordering key when a live
  /// update and a REST snapshot of the same vehicle meet.
  final DateTime updatedAt;

  bool get hasLocation => latitude != null && longitude != null;

  /// True if this copy is strictly newer than [other] (same vehicle). Equal is not newer: it's the same version.
  bool isNewerThan(Vehicle other) => updatedAt.isAfter(other.updatedAt);

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: readString(json, 'id'),
        fleetId: readString(json, 'fleetId'),
        fleetName: readString(json, 'fleetName'),
        name: readString(json, 'name'),
        model: readString(json, 'model'),
        serialNumber: readString(json, 'serialNumber'),
        status: readEnum(json, 'status', VehicleStatus.values, VehicleStatus.unknown),
        connectivity: readEnum(json, 'connectivity', Connectivity.values, Connectivity.unknown),
        latitude: readDoubleOrNull(json, 'latitude'),
        longitude: readDoubleOrNull(json, 'longitude'),
        speedKmh: readDoubleOrNull(json, 'speedKmh'),
        headingDeg: readDoubleOrNull(json, 'headingDeg'),
        batteryPct: readDoubleOrNull(json, 'batteryPct'),
        lastTelemetryAt: readDateOrNull(json, 'lastTelemetryAt'),
        lastSeenAt: readDateOrNull(json, 'lastSeenAt'),
        updatedAt: readDate(json, 'updatedAt'),
      );

  /// Changes only the given fields (nullable fields can't be cleared with this; nothing needs that).
  Vehicle copyWith({VehicleStatus? status, Connectivity? connectivity, DateTime? updatedAt}) => Vehicle(
        id: id,
        fleetId: fleetId,
        fleetName: fleetName,
        name: name,
        model: model,
        serialNumber: serialNumber,
        status: status ?? this.status,
        connectivity: connectivity ?? this.connectivity,
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
        headingDeg: headingDeg,
        batteryPct: batteryPct,
        lastTelemetryAt: lastTelemetryAt,
        lastSeenAt: lastSeenAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
