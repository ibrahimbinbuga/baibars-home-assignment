import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_provider.dart';
import '../../../core/json.dart';
import '../../activity/data/activity_event.dart';
import '../../activity/data/telemetry.dart';
import 'vehicle.dart';

/// Vehicle endpoints. The server decides which vehicles the user may see; this class never filters by permission.
class VehiclesRepository {
  VehiclesRepository(this._api);

  final ApiClient _api;

  /// [status] must not be [VehicleStatus.unknown].
  Future<List<Vehicle>> list({String? fleetId, VehicleStatus? status}) {
    assert(
      status != VehicleStatus.unknown,
      'unknown is a client-side value and cannot be sent to the API',
    );
    return _api.get(
      '/api/vehicles',
      query: {
        'fleetId': fleetId,
        'status': status == null ? null : apiEnumName(status),
      },
      parse: (json) => parseList(json, Vehicle.fromJson),
    );
  }

  /// Throws ApiException with statusCode 404 if the vehicle doesn't exist or is outside the user's fleets.
  Future<Vehicle> get(String vehicleId) => _api.get(
    '/api/vehicles/$vehicleId',
    parse: (json) => Vehicle.fromJson(asJsonMap(json)),
  );

  /// Defaults on the server: last hour, 500 points. Range at most 7 days; limit clamped to 2000.
  Future<TelemetryResponse> telemetry(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => _api.get(
    '/api/vehicles/$vehicleId/telemetry',
    query: {
      'from': from?.toUtc().toIso8601String(),
      'to': to?.toUtc().toIso8601String(),
      'limit': limit,
    },
    parse: (json) => TelemetryResponse.fromJson(asJsonMap(json)),
  );

  /// Pass [before] = previous page's nextBefore to get older events.
  Future<ActivityPage> activity(
    String vehicleId, {
    String? before,
    int? limit,
  }) => _api.get(
    '/api/vehicles/$vehicleId/activity',
    query: {'before': before, 'limit': limit},
    parse: (json) => ActivityPage.fromJson(asJsonMap(json)),
  );
}

final vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (ref) => VehiclesRepository(ref.watch(apiClientProvider)),
);
