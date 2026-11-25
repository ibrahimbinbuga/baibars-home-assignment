import 'dart:async';

import 'package:fleet_monitor/features/activity/data/activity_event.dart';
import 'package:fleet_monitor/features/activity/data/telemetry.dart';
import 'package:fleet_monitor/features/vehicles/data/fleet.dart';
import 'package:fleet_monitor/features/vehicles/data/fleets_repository.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';

/// Vehicles repository whose list() answers are queued by the test: a value, an error, or a pending Completer.
class FakeVehiclesRepository implements VehiclesRepository {
  final listAnswers = <FutureOr<List<Vehicle>> Function()>[];
  int listCalls = 0;
  final activityPages = <ActivityPage>[];
  Object? activityError;
  final activityBefores = <String?>[];

  @override
  Future<List<Vehicle>> list({String? fleetId, VehicleStatus? status}) async {
    listCalls++;
    return listAnswers.length > 1 ? await listAnswers.removeAt(0)() : await listAnswers.single();
  }

  @override
  Future<Vehicle> get(String vehicleId) async => (await list()).firstWhere((v) => v.id == vehicleId);

  @override
  Future<ActivityPage> activity(String vehicleId, {String? before, int? limit}) async {
    activityBefores.add(before);
    if (activityError != null) {
      final error = activityError!;
      activityError = null;
      throw error;
    }
    return activityPages.removeAt(0);
  }

  @override
  Future<TelemetryResponse> telemetry(String vehicleId, {DateTime? from, DateTime? to, int? limit}) async =>
      TelemetryResponse(from: DateTime.utc(2026), to: DateTime.utc(2026), items: const []);
}

class FakeFleetsRepository implements FleetsRepository {
  FakeFleetsRepository(this.fleets);

  final List<Fleet> fleets;

  @override
  Future<List<Fleet>> list() async => fleets;
}
