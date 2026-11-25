import 'dart:async';

import 'package:fleet_monitor/core/auth/auth_notifier.dart';
import 'package:fleet_monitor/core/auth/auth_state.dart';
import 'package:fleet_monitor/core/realtime/realtime_connection.dart';
import 'package:fleet_monitor/core/realtime/realtime_controller.dart';
import 'package:fleet_monitor/features/auth/data/auth_models.dart';

import 'package:fleet_monitor/features/activity/data/activity_event.dart';
import 'package:fleet_monitor/features/activity/data/telemetry.dart';
import 'package:fleet_monitor/features/vehicles/data/fleet.dart';
import 'package:fleet_monitor/features/vehicles/data/fleets_repository.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicle.dart';
import 'package:fleet_monitor/features/vehicles/data/vehicles_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vehicles repository whose list() answers are queued by the test: a value, an error, or a pending Completer.
class FakeVehiclesRepository implements VehiclesRepository {
  final listAnswers = <FutureOr<List<Vehicle>> Function()>[];
  int listCalls = 0;
  final activityPages = <ActivityPage>[];
  Object? activityError;

  /// If set, the next activity() call waits for it (to test events arriving during the first load).
  Completer<void>? activityGate;
  final activityBefores = <String?>[];

  @override
  Future<List<Vehicle>> list({String? fleetId, VehicleStatus? status}) async {
    listCalls++;
    return listAnswers.length > 1
        ? await listAnswers.removeAt(0)()
        : await listAnswers.single();
  }

  @override
  Future<Vehicle> get(String vehicleId) async =>
      (await list()).firstWhere((v) => v.id == vehicleId);

  @override
  Future<ActivityPage> activity(
    String vehicleId, {
    String? before,
    int? limit,
  }) async {
    activityBefores.add(before);
    final gate = activityGate;
    if (gate != null) {
      activityGate = null;
      await gate.future;
    }
    if (activityError != null) {
      final error = activityError!;
      activityError = null;
      throw error;
    }
    return activityPages.removeAt(0);
  }

  @override
  Future<TelemetryResponse> telemetry(
    String vehicleId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async => TelemetryResponse(
    from: DateTime.utc(2026),
    to: DateTime.utc(2026),
    items: const [],
  );
}

class FakeFleetsRepository implements FleetsRepository {
  FakeFleetsRepository(this.fleets);

  final List<Fleet> fleets;

  @override
  Future<List<Fleet>> list() async => fleets;
}

/// Realtime state pinned to "connected", for screen tests that aren't about the connection.
class StaticRealtimeController extends RealtimeController {
  StaticRealtimeController([
    this.fixed = const RealtimeState(RealtimeStatus.connected),
  ]);

  final RealtimeState fixed;

  @override
  RealtimeState build() => fixed;
}

/// A real-time connection driven by the test: start() can be delayed or fail; link events and messages are emitted
/// on demand. Records start/stop in [log].
class FakeRealtimeConnection implements RealtimeConnection {
  FakeRealtimeConnection(this.log, {this.onStart});

  final List<String> log;
  final Future<void> Function()? onStart;
  int starts = 0;
  int stops = 0;

  final vehicles = StreamController<Vehicle>.broadcast();
  final activity = StreamController<ActivityEvent>.broadcast();
  final link = StreamController<LinkEvent>.broadcast();

  @override
  Stream<Vehicle> get vehicleUpdates => vehicles.stream;

  @override
  Stream<ActivityEvent> get activityEvents => activity.stream;

  @override
  Stream<LinkEvent> get linkEvents => link.stream;

  @override
  Future<void> start() async {
    starts++;
    log.add('start');
    if (onStart != null) await onStart!();
  }

  @override
  Future<void> stop() async {
    stops++;
    log.add('stop');
  }
}

/// Auth that is simply "logged in until [expiresAt]"; logout only records the reason.
class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(this.expiresAt);

  final DateTime expiresAt;
  final logouts = <LogoutReason>[];

  static const user = UserInfo(
    id: 'u-1',
    email: 'admin@demo.local',
    displayName: 'Demo Admin',
    role: Role.admin,
  );

  @override
  Future<AuthState> build() async =>
      Authenticated(user: user, accessToken: 'jwt', expiresAt: expiresAt);

  @override
  Future<void> logout(LogoutReason reason) async {
    logouts.add(reason);
    state = AsyncData(Unauthenticated(reason));
  }
}
