import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';

/// A complete VehicleDto as the API sends it. Tests override fields with {...base, 'x': y}.
Map<String, dynamic> vehicleJson({
  String id = 'v-1',
  String status = 'Moving',
  String updatedAt = '2026-11-26T10:00:01.000001Z',
}) =>
    {
      'id': id,
      'fleetId': 'f-1',
      'fleetName': 'Tarsus Field Ops',
      'name': 'TR-01',
      'model': 'AgriRover X',
      'serialNumber': 'SN-0001',
      'status': status,
      'connectivity': status == 'Offline' ? 'Offline' : 'Online',
      'latitude': 36.92,
      'longitude': 34.89,
      'speedKmh': 12.4,
      'headingDeg': 270,
      'batteryPct': 76,
      'lastTelemetryAt': '2026-11-26T10:00:00Z',
      'lastSeenAt': '2026-11-26T10:00:01Z',
      'updatedAt': updatedAt,
    };

Vehicle vehicle({String id = 'v-1', String status = 'Moving', required DateTime updatedAt}) =>
    Vehicle.fromJson(vehicleJson(id: id, status: status, updatedAt: updatedAt.toUtc().toIso8601String()));
