import '../../../core/json.dart';

/// State as reported by the vehicle in one sample (never "offline": that is decided by the server).
enum VehicleState { moving, idle, charging, fault, unknown }

class TelemetryPoint {
  const TelemetryPoint({
    required this.sequence,
    required this.recordedAt,
    required this.receivedAt,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.headingDeg,
    required this.batteryPct,
    required this.state,
  });

  final int sequence;
  final DateTime recordedAt;
  final DateTime receivedAt;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double headingDeg;
  final double batteryPct;
  final VehicleState state;

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        sequence: readInt(json, 'sequence'),
        recordedAt: readDate(json, 'recordedAt'),
        receivedAt: readDate(json, 'receivedAt'),
        latitude: readDouble(json, 'latitude'),
        longitude: readDouble(json, 'longitude'),
        speedKmh: readDouble(json, 'speedKmh'),
        headingDeg: readDouble(json, 'headingDeg'),
        batteryPct: readDouble(json, 'batteryPct'),
        state: readEnum(json, 'state', VehicleState.values, VehicleState.unknown),
      );
}

/// History window. [from]/[to] are the window the server actually applied (after its defaults).
class TelemetryResponse {
  const TelemetryResponse({required this.from, required this.to, required this.items});

  final DateTime from;
  final DateTime to;

  /// Newest first.
  final List<TelemetryPoint> items;

  factory TelemetryResponse.fromJson(Map<String, dynamic> json) => TelemetryResponse(
        from: readDate(json, 'from'),
        to: readDate(json, 'to'),
        items: asJsonList(json['items']).map((e) => TelemetryPoint.fromJson(asJsonMap(e))).toList(growable: false),
      );
}
